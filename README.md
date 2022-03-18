<h2 align="center">
  <br>
  <a href="https://openwrt.org/"><img src="https://upload.wikimedia.org/wikipedia/commons/8/84/OpenWrt_Logo.svg" alt="OpenWrt" width="200"></a>
  <br>
  GitHub Actions Template
  <br>
</h2>
<h4 align="center">A simple <a href="https://github.com/features/actions" target="_blank">GitHub Actions Workflow</a> template to build <a href="https://openwrt.org/docs/guide-user/additional-software/imagebuilder" target="_blank">OpenWrt Image</a>.</h4>

<p align="center">
  <a href="https://badge.fury.io/js/electron-markdownify">
    <img alt="license" src="https://img.shields.io/github/license/mientz/imagebuilder-actions?style=flat-square">
  </a>
  <a href="https://github.com/mientz/imagebuilder-actions/actions" target="_blank">
    <img alt="GitHub Workflow Status" src="https://img.shields.io/github/workflow/status/mientz/imagebuilder-actions/Build%20Image?style=flat-square">
  </a>
  <a href="https://github.com/mientz/imagebuilder-actions/actions" target="_blank">
    <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/mientz/imagebuilder-actions?style=flat-square">
  </a>
  <br>
  <img alt="GitHub commits since latest release (by date including pre-releases)" src="https://img.shields.io/github/commits-since/mientz/imagebuilder-actions/latest?include_prereleases&style=flat-square">
</p>

## Key Features
* Support all OpenWrt release since 17.01.0.
* Support all targets and build profiles.
* Easier to build image for different targets.
  - Just use this repo template to build your OpenWrt image.
* Automatically create release with list of any packages included.
* Manually run the workflow to avoid rate limit.

## How To Use
1. On GitHub, navigate to the main page of this repository.
2. Above the file list, click Use this template.

<p align="center">
  <img alt="Use this template" src="https://docs.github.com/assets/images/help/repository/use-this-template-button.png">
</p>

3. Type a name for your repository, and an optional description.
4. Modify the [workflow](.github/workflows/build-openwrt.yml) file according to the target image you want to build.
5. Go to Actions. Under your repository name, click Actions.

<p align="center">
  <img alt="Use this template" src="https://docs.github.com/assets/images/help/repository/actions-tab.png">
</p>

6. In the left sidebar, click the workflow `Build Image`.

<p align="center">
  <img alt="Use this template" src="assets/workflow-sidebar.PNG">
</p>

7. in the `Build Image` workflows, click the **Run workflow**.

<p align="center">
  <img alt="Use this template" src="assets/run-workflow.png">
</p>

8. The log shows you how each of the steps was processed. Expand any of the steps to view its details

<p align="center">
  <img alt="Use this template" src="https://docs.github.com/assets/images/help/repository/actions-quickstart-logs.png">
</p>

## Acknowledgments
* [OpenWrt](https://github.com/openwrt/openwrt)
  Project is a Linux operating system targeting embedded devices. Instead
  of trying to create a single, static firmware, OpenWrt provides a fully
  writable filesystem with package management. This frees you from the
  application selection and configuration provided by the vendor and allows you
  to customize the device through the use of packages to suit any application.
  For developers, OpenWrt is the framework to build an application without having
  to build a complete firmware around it; for users this means the ability for
  full customization, to use the device in ways never envisioned.

* [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
  A GitHub Action for creating GitHub Releases on Linux, Windows, and macOS virtual environments