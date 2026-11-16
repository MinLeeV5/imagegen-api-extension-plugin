"""Exercise the installed CLI against a local fake API, without real credentials."""
import base64
from email.parser import BytesParser
from email.policy import default
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest

CLI = Path(__file__).resolve().parents[1] / 'plugins/imagegen-api/skills/imagegen-api/scripts/image_gen.py'
IMAGE = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1EAAAAASUVORK5CYII=')
REQUESTS = []


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        raw = self.rfile.read(int(self.headers['Content-Length']))
        content_type = self.headers.get('Content-Type', '')
        if content_type.startswith('multipart/'):
            message = BytesParser(policy=default).parsebytes(
                ('Content-Type: ' + content_type + '\r\nMIME-Version: 1.0\r\n\r\n').encode() + raw
            )
            payload = {
                part.get_param('name', header='content-disposition'): part.get_payload(decode=True)
                for part in message.iter_parts()
            }
            payload = {k: v.decode() if k not in ('image', 'image[]', 'mask') else v for k, v in payload.items()}
        else:
            payload = json.loads(raw)
        REQUESTS.append({'path': self.path, 'authorization': self.headers.get('Authorization'), 'payload': payload})
        reject = 'reject model' in payload.get('prompt', '')
        body = {'error': {'message': 'Model unavailable in fixture', 'type': 'invalid_request_error', 'code': 'model_not_found'}} if reject else {
            'created': 1793743200, 'data': [{'b64_json': base64.b64encode(IMAGE).decode()}]
        }
        encoded = json.dumps(body).encode()
        self.send_response(400 if reject else 200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, *args):
        pass


class ExtensionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self):
        REQUESTS.clear()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def run_cli(self, args, *, canonical=None, alias=None):
        env = os.environ.copy()
        for key in ('OPENAI_API_KEY', 'OPENAI_KEY', 'OPENAI_BASE_URL', 'OPENAI_PROJECT_ID', 'OPENAI_ORG_ID'):
            env.pop(key, None)
        env['OPENAI_BASE_URL'] = 'http://127.0.0.1:' + str(self.server.server_port) + '/v1'
        env['NO_PROXY'] = '127.0.0.1,localhost'
        if canonical is not None:
            env['OPENAI_API_KEY'] = canonical
        if alias is not None:
            env['OPENAI_KEY'] = alias
        result = subprocess.run([sys.executable, str(CLI)] + args, env=env, cwd=self.root,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=25)
        for value in (canonical, alias):
            if value and value.strip():
                self.assertNotIn(value.strip(), result.stdout + result.stderr)
        return result

    def test_generate_uses_default_26_flare_and_alias_key_without_input(self):
        out = self.root / 'duck.png'
        result = self.run_cli(['generate', '--prompt', 'A duck', '--out', str(out)], alias='fixture-alias-secret')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(out.read_bytes(), IMAGE)
        self.assertEqual(len(REQUESTS), 1)
        self.assertEqual(REQUESTS[0]['authorization'], 'Bearer fixture-alias-secret')
        self.assertEqual(REQUESTS[0]['path'], '/v1/images/generations')
        self.assertEqual(REQUESTS[0]['payload']['model'], 'gpt-image-2.6-flare')
        self.assertEqual(REQUESTS[0]['payload']['quality'], 'medium')
        self.assertEqual(REQUESTS[0]['payload']['size'], 'auto')
        self.assertEqual(REQUESTS[0]['payload']['output_format'], 'png')

    def test_edit_uses_default_26_flare(self):
        image = self.root / 'input.png'
        image.write_bytes(IMAGE)
        out = self.root / 'edited.png'
        result = self.run_cli(['edit', '--image', str(image), '--prompt', 'Preserve the duck',
                               '--out', str(out)], alias='fixture-edit-secret')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(out.read_bytes(), IMAGE)
        self.assertEqual(len(REQUESTS), 1)
        self.assertEqual(REQUESTS[0]['path'], '/v1/images/edits')
        self.assertEqual(REQUESTS[0]['payload']['model'], 'gpt-image-2.6-flare')
        self.assertEqual(REQUESTS[0]['payload']['image'], IMAGE)

    def test_edit_sunburst_and_canonical_key_precedence(self):
        image = self.root / 'input.png'
        image.write_bytes(IMAGE)
        out = self.root / 'edited.png'
        result = self.run_cli(['edit', '--image', str(image), '--prompt', 'Preserve the duck',
                               '--model', 'sunburst', '--size', '2160x3840', '--quality', 'max',
                               '--background', 'transparent', '--out', str(out)],
                              canonical='fixture-canonical-secret', alias='fixture-unused-secret')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(out.read_bytes(), IMAGE)
        self.assertEqual(REQUESTS[0]['path'], '/v1/images/edits')
        self.assertEqual(REQUESTS[0]['authorization'], 'Bearer fixture-canonical-secret')
        payload = REQUESTS[0]['payload']
        self.assertEqual(payload['model'], 'gpt-image-2.6-sunburst')
        self.assertEqual(payload['quality'], 'max')
        self.assertEqual(payload['size'], '2160x3840')
        self.assertEqual(payload['background'], 'transparent')

    def test_async_batch_normalizes_each_model_and_uses_alias_key(self):
        jobs = self.root / 'jobs.jsonl'
        jobs.write_text('\n'.join(json.dumps(job) for job in [
            {'prompt': 'A duck', 'model': 'flare', 'quality': 'xhigh', 'size': '3840x2160', 'out': 'duck.png'},
            {'prompt': 'A mug', 'model': 'sunburst', 'quality': 'max', 'out': 'mug.png'},
            {'prompt': 'A shell', 'out': 'shell.png'},
            {'prompt': 'A vase', 'model': 'image-2.6', 'out': 'vase.png'},
            {'prompt': 'A flower', 'model': 'gpt-image-2.5-flare', 'quality': 'max', 'out': 'flower.png'},
            {'prompt': 'A tree', 'model': 'gpt-image-2.5-sunburst', 'quality': 'xhigh', 'size': '2160x3840', 'out': 'tree.png'},
        ]))
        out = self.root / 'batch'
        result = self.run_cli(['generate-batch', '--input', str(jobs), '--out-dir', str(out),
                               '--concurrency', '2', '--no-augment'],
                              alias='fixture-async-secret')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(REQUESTS), 6)
        payloads = {r['payload']['prompt']: r['payload'] for r in REQUESTS}
        for subject, model in (
            ('duck', 'gpt-image-2.6-flare'), ('mug', 'gpt-image-2.6-sunburst'),
            ('shell', 'gpt-image-2.6-flare'), ('vase', 'gpt-image-2.6-flare'),
            ('flower', 'gpt-image-2.5-flare'), ('tree', 'gpt-image-2.5-sunburst'),
        ):
            with self.subTest(subject=subject):
                self.assertEqual((out / (subject + '.png')).read_bytes(), IMAGE)
                self.assertEqual(payloads['A ' + subject]['model'], model)
        self.assertEqual(payloads['A duck']['quality'], 'xhigh')
        self.assertEqual(payloads['A duck']['size'], '3840x2160')
        self.assertEqual(payloads['A mug']['quality'], 'max')
        self.assertEqual(payloads['A shell']['quality'], 'medium')
        self.assertEqual(payloads['A flower']['quality'], 'max')
        self.assertEqual(payloads['A tree']['quality'], 'xhigh')
        self.assertEqual(payloads['A tree']['size'], '2160x3840')
        self.assertTrue(all(r['authorization'] == 'Bearer fixture-async-secret' for r in REQUESTS))

    def test_dry_run_without_key_normalizes_26_aliases_and_preserves_full_models(self):
        for model, expected in (
            ('image-2.6', 'gpt-image-2.6-flare'),
            ('flare', 'gpt-image-2.6-flare'), ('sunburst', 'gpt-image-2.6-sunburst'),
            ('gpt-image-2.6-flare', 'gpt-image-2.6-flare'),
            ('gpt-image-2.6-sunburst', 'gpt-image-2.6-sunburst'),
            ('gpt-image-2.5-flare', 'gpt-image-2.5-flare'),
            ('gpt-image-2.5-sunburst', 'gpt-image-2.5-sunburst'),
        ):
            with self.subTest(model=model):
                result = self.run_cli(['generate', '--prompt', 'A duck', '--model', model,
                                       '--quality', 'max', '--size', '3840x2160',
                                       '--background', 'transparent', '--dry-run'])
                self.assertEqual(result.returncode, 0, result.stderr)
                payload = json.loads(result.stdout)
                self.assertEqual(payload['model'], expected)
                self.assertEqual(payload['quality'], 'max')
                self.assertEqual(payload['size'], '3840x2160')
                self.assertEqual(payload['background'], 'transparent')
        self.assertFalse(REQUESTS)

    def test_batch_dry_run_uses_default_26_flare(self):
        jobs = self.root / 'jobs.jsonl'
        jobs.write_text(json.dumps({'prompt': 'A duck'}))
        result = self.run_cli(['generate-batch', '--input', str(jobs),
                               '--out-dir', str(self.root / 'batch'), '--dry-run'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['model'], 'gpt-image-2.6-flare')
        self.assertFalse(REQUESTS)

    def test_rejects_invalid_options_before_network(self):
        for model in ('gpt-image-2', 'gpt-image-1.5'):
            with self.subTest(model=model):
                result = self.run_cli(['generate', '--prompt', 'A duck', '--model', model, '--quality', 'max', '--dry-run'])
                self.assertNotEqual(result.returncode, 0)
        for size in ('4000x2160', '1025x1024', '3840x1024', '256x256', '3072x3072'):
            with self.subTest(size=size):
                result = self.run_cli(['generate', '--prompt', 'A duck', '--size', size],
                                      alias='fixture-validation-secret')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('size', result.stderr)
        result = self.run_cli(['generate', '--prompt', 'A duck', '--background', 'transparent',
                               '--output-format', 'jpeg'], alias='fixture-validation-secret')
        self.assertNotEqual(result.returncode, 0)
        result = self.run_cli(['generate', '--prompt', 'A duck', '--quality', 'ultra'],
                              alias='fixture-validation-secret')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(REQUESTS)

    def test_missing_key_stops_without_network_or_confirmation(self):
        result = self.run_cli(['generate', '--prompt', 'A duck'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('OPENAI_KEY', result.stderr)
        self.assertFalse(REQUESTS)

    def test_error_preserves_model_without_fallback(self):
        for model, expected in (
            (None, 'gpt-image-2.6-flare'), ('sunburst', 'gpt-image-2.6-sunburst'),
            ('gpt-image-2.5-flare', 'gpt-image-2.5-flare'),
            ('gpt-image-2.5-sunburst', 'gpt-image-2.5-sunburst'),
        ):
            with self.subTest(model=model):
                REQUESTS.clear()
                args = ['generate', '--prompt', 'reject model']
                if model is not None:
                    args += ['--model', model]
                result = self.run_cli(args, canonical='fixture-error-secret')
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(REQUESTS), 1)
                self.assertEqual(REQUESTS[0]['payload']['model'], expected)
                self.assertFalse((self.root / 'output/imagegen/output.png').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
