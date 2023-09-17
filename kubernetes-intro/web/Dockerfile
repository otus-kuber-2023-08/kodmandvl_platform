FROM python:3.9
MAINTAINER Kodmandvl <kodmandvl@mail.ru>
COPY homework.html /app/homework.html
EXPOSE 8000
WORKDIR /app
USER 1001
ENTRYPOINT python -m http.server 8000
