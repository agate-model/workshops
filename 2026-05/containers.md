# Agate.jl Workshop Container Setup

This page explains how to install and run the container for the Agate.jl workshop.

The workshop uses Docker so that everyone can run the same software environment without having to install Julia packages, Oceananigans.jl, plotting tools, and workshop dependencies manually. Once the container is running, you will open the workshop environment in your web browser and work through the exercises there.

## Why we are using a container

Scientific software often depends on many packages, system libraries, and version-specific settings. A script that works on one computer may fail on another because the local software environments differ.

A container avoids much of this problem by packaging the software environment in advance. For this workshop, the container includes the tools needed to run the Agate.jl examples and exercises. You only need Docker Desktop to run that prepared environment on your own machine.

The container is separate from the rest of your computer. Files created inside the container may disappear when the container is removed unless you save them in a mounted folder or download them from Jupyter. During the workshop we will keep the workflow simple and explain where to save outputs.

## Step 1: Install Docker Desktop

Install Docker Desktop from:

<https://www.docker.com/products/docker-desktop/>

Choose the installer for your operating system:

- **macOS:** choose the correct version for your Mac, either Apple Silicon or Intel.
- **Windows:** Docker Desktop may ask you to restart your computer during installation.
- **Linux:** follow the Docker Desktop instructions for your distribution.

After installation, open Docker Desktop and wait until it says Docker is running.

Docker Desktop may ask you to sign in or create an account. You should be able to skip this for the workshop. If you already have a Docker account, signing in is also fine.

## Step 2: Download the workshop image

In Docker Desktop, open the **Images** section and search for:

```text
nanophyto/agate-workshops
```

Pull the workshop image with the tag:

```text
2026-05-22
```

The full image name is:

```text
nanophyto/agate-workshops:2026-05-22
```

The download may take some time. Please make sure you have a stable internet connection and enough free disk space before starting.

### Terminal option

If you are comfortable using a terminal, you can pull the image with:

```bash
docker pull nanophyto/agate-workshops:2026-05-22
```

This does the same thing as pulling the image through Docker Desktop.

## Step 3: Start the workshop container

Once the image has downloaded, start it from Docker Desktop.

1. Go to **Images**.
2. Find `nanophyto/agate-workshops`.
3. Select the `2026-05-22` tag.
4. Click **Run**.
5. Open **Optional settings**.

Use the following settings:

| Setting | Value |
|---|---|
| Container name | `agate-workshop` |
| Host port | `8888` |
| Container port | `8888` |

If port `8888` is already in use on your computer, use another host port such as `8890`. Keep the container port as `8888`.

Click **Run** to start the container.

On Windows, you may be asked whether Docker is allowed to access private or public networks. Allow access so that your browser can connect to the Jupyter server running inside the container.

### Terminal option

If you prefer the terminal, you can start the container with:

```bash
docker run --rm -p 8888:8888 nanophyto/agate-workshops:2026-05-22
```

If port `8888` is already busy, use for example:

```bash
docker run --rm -p 8890:8888 nanophyto/agate-workshops:2026-05-22
```

In that case, open `http://localhost:8890` instead of `http://localhost:8888`.

## Step 4: Open Jupyter in your browser

After the container starts, open your web browser and go to:

<http://localhost:8888>

If you used a different host port, replace `8888` with that number. For example:

<http://localhost:8890>

You should see Jupyter Lab or a similar notebook interface. This is where we will run the workshop examples.

If Jupyter asks for a token or password, check the container logs in Docker Desktop. The startup message should contain a URL with the required token. Copy that full URL into your browser.

## Step 5: Check that the environment works

Inside Jupyter, open the setup-check notebook or script provided with the workshop materials. Run the first few cells or run the setup check script.

The check should confirm that Julia starts and that the main workshop packages can be loaded.

If something fails, please make a note of the error message and bring it to the workshop. We will have fallback options, and you can also work in pairs if needed.

## Saving your work

The workshop container provides a reproducible environment, but it is not the best long-term place to store your only copy of important work.

During the workshop, save notebooks and figures regularly. At the end of the day, download any files you want to keep from Jupyter to your own computer.

If you run the container with a mounted folder, files saved in that mounted folder will also be visible on your computer. We will keep this optional so that the basic setup remains simple.

## Stopping and restarting the container

You can stop the container from Docker Desktop:

1. Open the **Containers** section.
2. Find `agate-workshop`.
3. Click the stop button.

To restart it later, press the play button next to the same container, or start a new container from the image.

Before stopping the container, save your notebooks and download anything you want to keep.

## Troubleshooting

### Docker Desktop is not running

Open Docker Desktop and wait until it has finished starting. Docker commands and containers will not work until Docker Desktop is running.

### The image cannot be found

Check the spelling of the image name:

```text
nanophyto/agate-workshops:2026-05-22
```

Make sure you are searching for `nanophyto/agate-workshops`, not `agate-workshops` alone.

### The browser page does not open

Check that the container is running in Docker Desktop. Also check that you are using the correct port.

If you set the host port to `8888`, open:

<http://localhost:8888>

If you set the host port to `8890`, open:

<http://localhost:8890>

### Port 8888 is already in use

Use a different host port when starting the container, such as `8890`. The container port should still be `8888`.

### The container starts but Jupyter asks for a token

Open the container logs in Docker Desktop and copy the full Jupyter URL shown there. It should include a token.

### I cannot install Docker Desktop on my laptop

Please let the organiser know before the workshop. You may be able to pair with another participant, use a shared machine, or work from precomputed outputs.

## For people who already use containers

Experienced users can use their preferred Docker-compatible workflow. The workshop image is:

```text
nanophyto/agate-workshops:2026-05-22
```

A minimal command is:

```bash
docker run --rm -p 8888:8888 nanophyto/agate-workshops:2026-05-22
```

## Building the image

The workshop repository includes the Dockerfile used to build the image. You do not need to build the image yourself for the workshop, but the Dockerfile is included so that the environment can be inspected, modified, and rebuilt later.