# Jenkins

Documentation for my [Jenkins pipelines](../../../.jenkins/).

## Connecting to Github

To run pipelines from Github, you can use a [Github App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app) or [Personal Access Token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

### Connect with a Github App

Create a Github App with a name like `Jenkins` or `Jenkins-Homelab`. Depending on if your Jenkins instance is reachable from Github/the Internet or not, you will need to use different configurations.

After creating the app, save the App ID and Client ID, then generate a client secret and save it somewhere secure. Scroll down and generate a private key. You will need to convert this key to PKCS#8 format (you can also use the [`convert-github-privatekey.sh` script](./scripts/convert-github-privatekey.sh)):

```shell
openssl pkcs8 -topk8 -inform PEM -outform PEM -in yourappname.YYYY-mm-dd.private-key.pem -out converted.yourappname.pem -nocrypt
```

Then, go to "Install App" and install the app to your user/organization.

To add the Github App as a credential, open Jenkins' settings and go to "Credentials," then "Github App." Add the app ID and paste the secret you generated. You can choose to limit the scope to specific repositories or infer from pipelines (grant access as needed).

#### Github App Permissions Table

| Field                                                  | Local-only Jenkins                              | Internet-reachable Jenkins                                   | Example value                                           |
| ------------------------------------------------------ | ----------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------- |
| App name                                               | Required                                        | Required                                                     | `JenkinsBot`                                            |
| Homepage URL                                           | Optional                                        | Optional                                                     | `https://github.com/username-or-org/repo-name`          |
| Callback URL                                           | Not needed for repo access                      | Required only if using GitHub user-login/OAuth               | `https://jenkins.example.com/securityRealm/finishLogin` |
| Request user authorization (OAuth) during installation | Not needed                                      | Optional, only for user auth flows                           | Off                                                     |
| Enable Device Flow                                     | Not needed                                      | Optional, only for device-based user login                   | Off                                                     |
| Setup URL                                              | Not needed                                      | Optional, only if you want a post-install landing page       | `https://jenkins.example.com/github-app-setup`          |
| Redirect on update                                     | Not needed                                      | Optional, only with a Setup URL flow                         | Off                                                     |
| Webhook URL                                            | Not needed if GitHub cannot reach Jenkins       | Required if you want GitHub to trigger Jenkins automatically | `https://jenkins.example.com/github-webhook/`           |
| Webhook secret                                         | Optional if no webhook usage                    | Recommended if using webhooks                                | `long-random-secret`                                    |
| Repository permissions: Metadata                       | Required                                        | Required                                                     | Read-only                                               |
| Repository permissions: Contents                       | Required for checkout / Jenkinsfile reading     | Required for checkout / Jenkinsfile reading                  | Read-only                                               |
| Repository permissions: Pull requests                  | Optional, if you want PR info                   | Optional, if you want PR info                                | Read-only                                               |
| Repository permissions: Commit statuses                | Optional, if Jenkins should report build status | Optional, if Jenkins should report build status              | Read & write                                            |
| Repository permissions: Checks                         | Optional, if Jenkins should create check runs   | Optional, if Jenkins should create check runs                | Read & write                                            |
| Organization permissions                               | Usually not needed                              | Usually not needed unless you need org/team data             | Off                                                     |
| Account permissions                                    | Not needed                                      | Only needed for user-auth/login flows                        | Off                                                     |
| Installation scope                                     | Only on this account is fine                    | "Any account" if you plan to reuse it in an org              | "Only on this account"                                  |

### Connect with a Personal Access Token (PAT)

If you do not need the webhook functionality a Github App provides, you can also just use a PAT.

#### PAT Permissions Table

| Permission                                  | Required/Optional                                     | Purpose                                                                                                       |
| ------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Repository contents                         | Required                                              | Lets Jenkins clone the repo and read files like Jenkinsfile github.                                           |
| Repository metadata                         | Required                                              | Lets Jenkins discover repo/basic information; this is commonly needed for GitHub API interactions github.     |
| Pull requests                               | Optional                                              | Useful if Jenkins needs to inspect PRs or run PR-based multibranch jobs github.                               |
| Commit statuses                             | Optional, useful                                      | Lets Jenkins update the commit status shown in GitHub after a build cloudbees.                                |
| Checks                                      | Optional, useful                                      | Lets Jenkins create GitHub check runs/checks output instead of only commit statuses github.                   |
| Workflows                                   | Usually not needed                                    | Only needed if Jenkins is directly managing GitHub Actions workflows, which is uncommon for Jenkins github.   |
| Contents: write                             | Optional, only if you push tags/commits               | Needed if Jenkins will write back to the repo, such as tagging releases or committing generated files github. |
| Pull requests: write                        | Optional, only if Jenkins comments or edits PRs       | Needed if Jenkins will modify PR state or write PR-related data github.                                       |
| Administration / repository hook management | Optional, only if Jenkins must create/manage webhooks | Needed if you want Jenkins to manage repository hooks rather than setting them manually cloudbees.            |
| Organization permissions                    | Usually not needed                                    | Only needed if Jenkins needs org-level data such as teams or organization resources github.                   |
| Account permissions                         | Usually not needed                                    | Mostly relevant for user-auth/login flows, not normal Jenkins checkout jobs github.                           |
