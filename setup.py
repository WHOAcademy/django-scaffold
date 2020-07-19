from setuptools import setup, find_packages

setup(name='django-scaffold',
      version='1.0',
      packages=find_packages(),
      install_requires=[
            'Django',
            'psycopg2-binary',
            'djangorestframework',
      ],
      scripts=['manage.py'])