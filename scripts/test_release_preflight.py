"""Tests for preventing accidental development configuration in release artifacts."""
import unittest
from release_preflight import errors,public_https

class ReleasePreflightTests(unittest.TestCase):
    def valid(self):return {'API_BASE_URL':'https://api.belonkhon.vn/api/v1','DEMO_MODE':'false',
        'GOOGLE_SERVER_CLIENT_ID':'public-client.apps.googleusercontent.com','GOOGLE_IOS_CLIENT_ID':'public-ios.apps.googleusercontent.com',
        'APPLE_SERVICE_ID':'vn.belonkhon.service','APPLE_REDIRECT_URI':'https://api.belonkhon.vn/auth/apple/callback'}
    def test_public_config(self):self.assertEqual(errors(self.valid(),'android'),[])
    def test_local_and_insecure_urls(self):
        for value in ('http://api.belonkhon.vn','https://127.0.0.1','https://192.168.1.2','https://localhost','https://api.invalid','https://user:secret@api.belonkhon.vn'):
            with self.subTest(value=value):self.assertFalse(public_https(value))
    def test_secret_and_demo_rejected(self):
        config=self.valid();config.update(AUTH_SECRET='never-bundle',DEMO_MODE='true')
        self.assertEqual(len(errors(config,'android')),2)
    def test_ios_needs_explicit_client(self):
        config=self.valid();del config['GOOGLE_IOS_CLIENT_ID'];self.assertTrue(errors(config,'ios'))

if __name__=='__main__':unittest.main()
