# Context
This is an Upwork freelance project. The goal is to implement the project to optimize the client satisfaction, and you are my assistant to help me implement the project.
A proposal accepted by the client is available at 'proposal.md' (milestones are described in the proposal).
The initial project description written by the client is available at 'project_description.md'.

# Rules
Some rules that you should follow are in rules.md (notably Flutter best practices).

# Milestones
Milestones are described in milestones/ directory.
Before implementing a milestone, create an md file for it to document the implementation.
Each milestone file has user stories with description of each page/tab of the app that you must implement. Before implementing the milestone, ask me to confirm the md file content.
The milestone file must be updated when changes are asked and made.

# Tests
Execute the full test suite with `flutter test`. If failures occur,
fix them one by one. After applying each fix, re-run the full suite one
last time to ensure no regressions. Tests instructions are available in rules.md.
Run `flutter analyze` over my project. If it fails, fix any errors and warnings, then validate that they are fixed.

# README
Update README.md when a milestone is completed. It should contain a short explonation of the project, how to run the app, the features and details on how to use each feature. This constitutes the documentation of the app that will be given to the client, so make it very clear and easy to understand. Note that client is not technical, so make it simple and explain each feature. Also, add instructions on how to install the app on his phone.

# Github
Use Github for version control.
Use clear commit messages.
Create dedicated branch when beginning a milestone and create pull request when the milestone is completed. I will then accept it or reject it based on the quality of the code. If rejected, I will provide feedback on how to change the code. If accepted, I will merge the branch into the main branch.
Create a CI/CD pipeline to automatically build and deploy the app when a pull request is accepted.

## Workflow Steps (Tying it all together)

### Start Milestone 1:

Create the branch from main: git checkout -b milestone/M1-app-foundation main

### Work and Commit:

Commit changes often with clear commit messages.

### Complete and Review:

When the milestone is complete (analysis passes, tests pass), create a Pull Request from milestone/M1-app-foundation to main.

### Accept and Merge (The Merge Point):

Once the PR is accepted, merge the branch into main. The CI/CD pipeline runs at this point to build the app.

### Tag the Deliverable:

Immediately after the merge, create the tag: git tag -a M1.0.0 -m "Delivered and Accepted Milestone 1"

Push the tag to the remote repository: git push --tags

# Theme
The main color is blue.