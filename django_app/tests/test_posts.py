from django.test import SimpleTestCase
from django_app.models import Post


class TestPosts(SimpleTestCase):
    def setUp(self):
        self.post = Post(author_id=1, title="Title", text="text", created_date="", published_date="")

    def test_title(self):
        self.assertEqual(self.post.get_title(), "Title")
