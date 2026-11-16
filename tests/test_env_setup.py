"""Run environment installers with temporary profiles and fixture credentials."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
PWSH = os.environ.get('CODEX_ENV_TEST_PWSH') or shutil.which('pwsh') or shutil.which('powershell')
KEY = 'fixture-provider-secret'
BASE_URL = 'https://images.example/v1'


class InstallerChecks:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "setup files' space"
        self.root.mkdir()
        self.config = self.root / 'config.toml'
        self.install_dir = self.root / "loader's directory"
        self.startup_dir = self.root / 'profiles'
        self.startup_dir.mkdir()
        self.env = os.environ.copy()
        for key in list(self.env):
            if key.startswith(('OPENAI_', 'CODEX_ENV_')):
                self.env.pop(key)
        self.env.update({
            'CODEX_ENV_CONFIG': str(self.config),
            'CODEX_ENV_INSTALL_DIR': str(self.install_dir),
            'CODEX_ENV_STARTUP_DIR': str(self.startup_dir),
            'SHELL': '/bin/zsh',
            'POWERSHELL_TELEMETRY_OPTOUT': '1',
        })
        self.write_provider()

    def write_provider(self, *, credentials=None, base_url=BASE_URL):
        if credentials is None:
            credentials = f"experimental_bearer_token = '{KEY}'"
        self.config.write_text(
            'model_provider = "fixture"\n'
            '[model_providers.unused]\n'
            'base_url = "https://unused.example/v1"\n'
            'experimental_bearer_token = "fixture-unused-secret"\n'
            '[model_providers.fixture]\n'
            f'base_url = "{base_url}" # selected endpoint\n'
            f'{credentials}\n', encoding='utf-8',
        )

    def run_command(self, args, *, expected_code=0):
        result = subprocess.run(args, env=self.env, cwd=self.root,
                                capture_output=True, text=True, timeout=25)
        self.assertNotIn(KEY, result.stdout + result.stderr)
        self.assertNotIn('fixture-existing-secret', result.stdout + result.stderr)
        if expected_code is not None:
            self.assertEqual(result.returncode, expected_code, result.stdout + result.stderr)
        return result

    def test_installs_and_loads_active_provider_without_exposing_key(self):
        self.install()
        self.check_loaded(KEY, BASE_URL)
        for profile in self.profiles:
            contents = profile.read_text(encoding='utf-8-sig')
            self.assertEqual(contents.count('# >>> codex-env >>>'), 1)
            self.assertNotIn(KEY, contents)
        self.assertNotIn(KEY, self.loader.read_text(encoding='utf-8-sig'))

    def test_reinstall_preserves_existing_profiles_and_makes_one_backup(self):
        for profile in self.profiles:
            profile.parent.mkdir(parents=True, exist_ok=True)
            profile.write_text('# existing user settings\n', encoding='utf-8')
        self.install()
        first = {profile: profile.read_bytes() for profile in self.profiles}
        self.install()
        for profile in self.profiles:
            self.assertEqual(profile.read_bytes(), first[profile])
            self.assertIn('# existing user settings', profile.read_text(encoding='utf-8-sig'))
            backups = list(profile.parent.glob(profile.name + '.codex-env-backup-*'))
            backups += list(profile.parent.glob(profile.name + '.codex-env-backup.*'))
            self.assertEqual(len(backups), 1)

    def test_env_key_has_precedence_and_config_changes_are_reloaded(self):
        self.env['FIXTURE_PROVIDER_KEY'] = KEY
        self.write_provider(credentials='env_key = "FIXTURE_PROVIDER_KEY"\n'
                            'experimental_bearer_token = "fixture-unused-secret"')
        self.install()
        self.check_loaded(KEY, BASE_URL)
        self.write_provider(base_url='https://updated.example/v1')
        self.check_loaded(KEY, 'https://updated.example/v1')

    def test_missing_or_invalid_config_preserves_existing_environment(self):
        self.install()
        self.env.update({'OPENAI_API_KEY': 'fixture-existing-secret',
                         'OPENAI_BASE_URL': 'https://existing.example/v1'})
        self.config.unlink()
        self.check_loaded('fixture-existing-secret', 'https://existing.example/v1')
        self.write_provider(credentials='env_key = "FIXTURE_MISSING_KEY"')
        self.check_loaded('fixture-existing-secret', 'https://existing.example/v1')
        self.write_provider(credentials='experimental_bearer_token = "unterminated')
        self.check_loaded('fixture-existing-secret', 'https://existing.example/v1')

    def test_values_are_data_and_never_evaluated_as_commands(self):
        marker = self.root / 'unexpected-command'
        # Use a simple relative marker so the same literal works in either shell.
        value = '$(echo evaluated > unexpected-command)'
        self.write_provider(credentials=f"experimental_bearer_token = '{value}'")
        self.install()
        self.check_loaded(value, BASE_URL)
        self.assertFalse(marker.exists())


@unittest.skipUnless(shutil.which('sh'), 'POSIX shell unavailable')
class ShellInstallerTest(InstallerChecks, unittest.TestCase):
    @property
    def loader(self):
        return self.install_dir / 'env.sh'

    @property
    def profiles(self):
        return [self.startup_dir / name for name in ('.zshenv', '.zshrc', '.zprofile')]

    def install(self):
        self.run_command(['sh', str(SCRIPTS / 'setup-codex-env.sh')])

    def check_loaded(self, key, base_url):
        self.env['CODEX_ENV_TEST_KEY'] = key
        self.env['CODEX_ENV_TEST_URL'] = base_url
        self.run_command(['sh', '-c', '. "$1"; '
                          'test "$OPENAI_API_KEY" = "$CODEX_ENV_TEST_KEY" && '
                          'test "$OPENAI_BASE_URL" = "$CODEX_ENV_TEST_URL"',
                          'env-check', str(self.loader)])

    def test_zsh_noninteractive_session_loads_installed_profile(self):
        if not shutil.which('zsh'):
            self.skipTest('Zsh unavailable')
        self.install()
        self.env['ZDOTDIR'] = str(self.startup_dir)
        self.env['CODEX_ENV_TEST_KEY'] = KEY
        self.env['CODEX_ENV_TEST_URL'] = BASE_URL
        self.run_command(['zsh', '-c', 'test "$OPENAI_API_KEY" = "$CODEX_ENV_TEST_KEY" && '
                          'test "$OPENAI_BASE_URL" = "$CODEX_ENV_TEST_URL"'])
        self.assertEqual(self.loader.stat().st_mode & 0o777, 0o600)

    def test_bash_keeps_existing_login_profile(self):
        self.env['SHELL'] = '/bin/bash'
        profile = self.startup_dir / '.profile'
        profile.write_text('# existing login settings\n', encoding='utf-8')
        self.install()
        self.assertFalse((self.startup_dir / '.bash_profile').exists())
        self.assertTrue((self.startup_dir / '.bashrc').is_file())
        self.assertIn('# existing login settings', profile.read_text())
        self.env['CODEX_ENV_TEST_KEY'] = KEY
        self.run_command(['bash', '--noprofile', '--norc', '-c',
                          '. "$1"; test "$OPENAI_API_KEY" = "$CODEX_ENV_TEST_KEY"',
                          'env-check', str(profile)])

    def test_strict_diagnostics_fail_without_printing_secrets(self):
        self.install()
        self.config.unlink()
        self.env['CODEX_ENV_STRICT'] = '1'
        result = self.run_command(['sh', str(self.loader)], expected_code=None)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('codex-env:', result.stderr)


@unittest.skipUnless(PWSH, 'PowerShell unavailable; set CODEX_ENV_TEST_PWSH to its executable')
class PowerShellInstallerTest(InstallerChecks, unittest.TestCase):
    @property
    def loader(self):
        return self.install_dir / 'env.ps1'

    @property
    def profiles(self):
        return [self.startup_dir / name / 'profile.ps1' for name in ('WindowsPowerShell', 'PowerShell')]

    def install(self):
        self.env['CODEX_ENV_TEST_INSTALLER'] = str(SCRIPTS / 'setup-codex-env.ps1')
        # Simulate a profile-compatible policy without changing the host policy.
        self.run_command([PWSH, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
                          "function Get-ExecutionPolicy { param([switch] $List) "
                          "[pscustomobject]@{ Scope = 'CurrentUser'; ExecutionPolicy = 'RemoteSigned' } }; "
                          '& $env:CODEX_ENV_TEST_INSTALLER -NoPersist'])

    def check_loaded(self, key, base_url):
        self.env['CODEX_ENV_TEST_LOADER'] = str(self.loader)
        self.env['CODEX_ENV_TEST_KEY'] = key
        self.env['CODEX_ENV_TEST_URL'] = base_url
        self.run_command([PWSH, '-NoLogo', '-NoProfile', '-Command',
                          "$ErrorActionPreference = 'Stop'; & $env:CODEX_ENV_TEST_LOADER; "
                          'if ($env:OPENAI_API_KEY -cne $env:CODEX_ENV_TEST_KEY -or '
                          "$env:OPENAI_BASE_URL -cne $env:CODEX_ENV_TEST_URL) { throw 'Environment mismatch' }"])

    def test_loader_remembers_explicit_config_path(self):
        self.install()
        self.env.pop('CODEX_ENV_CONFIG')
        self.check_loaded(KEY, BASE_URL)
        self.assertTrue(self.loader.read_bytes().startswith(b'\xef\xbb\xbf'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
