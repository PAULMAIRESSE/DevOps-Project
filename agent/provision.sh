export vm1=192.168.56.10
export vm2=192.168.56.11

echo "Provisioning Vagrant box for GitLab Runner..."
echo "Setting up environment variables..."
export DEBIAN_FRONTEND=noninteractive

# Update package list and install necessary packages
echo "Updating package list and installing necessary packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null
# Install curl for downloading scripts
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl > /dev/null


# The next steps focus on the green and yellow parts: 
# - Install Docker (this is for the GitLab Runner)
# - Install Podman
# - Connect to Docker Hub
# - Pull and run an Ubuntu container
# - Install WordPress using Podman
# - Set up port direction from wordpress to guest@localhost:8080

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null
sudo sh get-docker.sh > /dev/null
# Add user to Docker group
sudo usermod -aG docker $USER
# Enable and start Docker service
sudo systemctl enable docker > /dev/null 2>&1
sudo systemctl start docker > /dev/null 2>&1
# Print Docker version
echo "Docker version: $(docker --version | awk '{print $3}')"
# Install Docker Compose
echo "Installing Docker Compose..."
# Download the latest version of Docker Compose
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose > /dev/null
# Print Docker Compose version
echo "Docker Compose version: $(docker-compose --version | awk '{print $3}')"

# Next, we will focus on the red part: 
# linking this Vagrant box to the other one
# by registering this box as a "Docker socket agent pool" for the other box's GitLab. 
# When the pipeline is triggered by the other box, a container will be created here to execute the job; at the end of the job, the container will be removed.

# Add the official GitLab repository
echo "Installing GitLab Runner..."
# This will allow us to install the latest version of GitLab Runner
curl -fsSL "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash > /dev/null && \
sudo DEBIAN_FRONTEND=noninteractive apt-get install gitlab-runner -y > /dev/null # Install the latest version of GitLab Runner

echo "GitLab Runner version: $(gitlab-runner --version | awk '{print $3}')"

# Make sure inotify-tools is installed for waiting on file creation
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl inotify-tools > /dev/null


if [ ! -f /home/vagrant/runner_access_token.txt ]; then
    echo "Waiting for runner_access_token.txt to be created or modified..."
    # Use inotifywait to await the access token
    inotifywait -m -e create -e modify /home/vagrant | while read path action file; do
    if [ "$file" = "runner_access_token.txt" ]; then
        echo "runner_access_token.txt has been created or modified."
        # Register the GitLab Runner, using the token from the file created by the other box
        sudo gitlab-runner register --non-interactive --url http://$vm1 --executor docker --docker-image "docker:latest" --token $(cat /home/vagrant/runner_access_token.txt) 
        break
    else
        echo "Another file was modified: $file"
    fi
done
else
    echo "Error: runner_access_token.txt already exists. Skipping wait and registration."
fi