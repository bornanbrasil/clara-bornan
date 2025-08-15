# Project Setup Guide

Complete guide to setting up and running Chatwoot in development mode.

---

## Project Setup

This guide will help you to setup and run Chatwoot in development mode.
Please make sure you have completed the environment setup.

---

## Install Dependencies

```shell
make burn
```

This will install all required dependencies for the Chatwoot application.
If you face issues with the `pg` gem, please refer to **Common Errors**.

---

## Setup environment variables

```shell
cp .env.example .env
```

Please refer to **environment-variables** to learn about setting environment variables.

---

## Setup Rails server

### Run DB migrations

```postgres
make db
```

### Fire up the server

```shell
foreman start -f Procfile.dev
```

---

## Endpoint Access

Access: <http://localhost:3000>

---
