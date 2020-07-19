FROM image-registry.openshift-image-registry.svc:5000/openshift/python-38:latest

ENV PYTHONUNBUFFERED 1

ARG build_url=default
ARG git_commit=default
ARG git_url=default

LABEL labs.build.url="${build_url}" \
      labs.git.tag="${git_commit}" \
      labs.git.url="${git_url}"

RUN pip install -r requirements.txt

COPY . $HOME