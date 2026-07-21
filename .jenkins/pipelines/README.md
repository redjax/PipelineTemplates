# Jenkins Pipelines

Centralized Jenkins pipelines.

To use a pipeline in this repository, create a new pipeline in Jenkins and use "Pipeline script from SCM" as the pipeline definition. Choose "Git" for the SCM (you must have the git plugin for Jenkins installed), give it a repository URL, and either a Github App ID/secret or username + PAT. Under "Advanced," give it a name `origin` and use a refspec like `+refs/heads/*:refs/remotes/origin/*`.

Set the "Script Path" value to a pipeline in this repository, i.e. `.jenkins/pipelines/demo/hello-world/Jenkinsfile`. If the pipeline takes inputs, you can set them in the definition with optional default values, and you will be prompted to change them when you run the build.
