FROM registry.access.redhat.com/rhscl/nginx-112-rhel7

ENV PYTHONUNBUFFERED 1

ARG build_url=default
ARG git_commit=default
ARG git_url=default

LABEL labs.build.url="${build_url}" \
      labs.git.tag="${git_commit}" \
      labs.git.url="${git_url}"

RUN pip install -r requirements.txt

COPY dist $HOME
CMD ["nginx", "-g", "daemon off;"]