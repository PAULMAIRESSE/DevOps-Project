DevOps Project
===
# Tech Stack 

On Windows 11: 
- Architecture: x64  
- CPU: AMD Ryzen 5 5600U 
- RAM: 16 Go 
- Vagrant v2.4.6
- VirtualBox v7.1.6

--- 
# Start up 
We use two Vagrant boxes: master and agent.  
To launch them, use two terminals and run these two commands: 
```sh
cd master; vagrant up
```
and 
```sh
cd agent; vagrant up 
```

---
# Description

## Master VM 

Master will create a complete GitLab development environment, with a pre-configured project, ready for collaborative development and CI/CD workflows.  
It will interact with Agent VM to set it as a GitLab runner, so that it runs the tasks for Master. 

More precisely, it installs GitLab. Then, it creates a GitLab instance runner and shares the token to Agent via SSH. Finally, it clones a web project from the internet and pushes a commit to this project. This triggers the CI/CD pipeline of this project, which is handled by Agent.  

## Agent VM

As an agent of Master's GitLab, it installs Docker and it will set itself up as a runner using the token that Master sends to it. 
