export vm1=192.168.56.10
export vm2=192.168.56.11

echo "Provisioning Vagrant box for GitLab..."
echo "Setting up environment variables..."
export DEBIAN_FRONTEND=noninteractive

sudo DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl > /dev/null

# Disable Apache2
sudo systemctl stop apache2 > /dev/null 2>&1
sudo systemctl disable apache2 > /dev/null 2>&1

# Check if Apache2 is running
if systemctl is-active --quiet apache2; then
    echo "Error: Apache2 is running. Please stop it before proceeding."
    exit 1
else
    echo "Apache2 is not running anymore. Proceeding with GitLab installation."
fi

# Install Gitlab
echo "Installing GitLab..."
# Add the official GitLab repository
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash > /dev/null
sudo EXTERNAL_URL="http://$vm1" apt-get install -y gitlab-ce > /dev/null


# Configure Gitlab
sudo gitlab-ctl reconfigure

# Enable and start Gitlab service
sudo systemctl enable gitlab-runsvdir > /dev/null 2>&1
sudo systemctl start gitlab-runsvdir > /dev/null 2>&1



# Print Gitlab status
sudo gitlab-ctl status
# Print Gitlab version
gitlab_version=$(gitlab-rake gitlab:env:info | grep "GitLab version" | awk '{print $3}')
echo "GitLab version: $gitlab_version"
# Print Gitlab URL
echo "GitLab is running at http://$vm1"

# Create a directory for GitLab 
mkdir -p ~/gitlab

echo "Creating GitLab project directory..."
# Create a Courriel gitlab project
gitlab_project_name="Courriel"
gitlab_project_description="Courriel project for secure email management"

# Generate a random token for GitLab API access
token_name="automation_token"
token_string="outgoing-affix-trustless-hubcap-borax"
token=$(openssl rand -base64 32 | tr -d '/+' | cut -c1-32)
scopes="'api', 'sudo'"

# Print the generated token
echo "Generated token: $token"

# Get token from gitlab rails console
export gitlab_token=$(sudo gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: [$scopes],name: '$token_name',expires_at: 365.days.from_now); token.set_token('$token'); token.save!; puts token.token") && \
echo "GitLab token: $gitlab_token"  # Print the GitLab token


# Create a new GitLab instance runner
# and get the access token from the JSON response
sudo DEBIAN_FRONTEND=noninteractive apt-get install jq -y > /dev/null
curl --request POST "http://$vm1/api/v4/user/runners" \
  --header "PRIVATE-TOKEN: $gitlab_token" \
  --form "runner_type=instance_type" | jq -r '.token' | tee ~/gitlab/runner_access_token.txt

echo "GitLab Runner access token saved to ~/gitlab/runner_access_token.txt"
# Send the GitLab Runner token to the other VM
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sshpass  # for SSH authentication via password
# Send the file with "scp" via SSH (using the password "vagrant" for authentication), 
#  without checking the host key, 
#  at the destination path "~/runner_access_token.txt" on the other VM
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no ~/gitlab/runner_access_token.txt vagrant@$vm2:~/runner_access_token.txt && echo "File sent to $vm2"
echo "GitLab Runner access token sent to $vm2"


# Create a new project using GitLab API
curl --request POST "http://$vm1/api/v4/projects" \
     --header "PRIVATE-TOKEN: $gitlab_token" \
     --form "name=$gitlab_project_name" \
     --form "description=$gitlab_project_description" \
     --form "visibility=public"

# Install git
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git > /dev/null

# Clone the new project and push local files (assuming synced in /vagrant)
git clone "http://$vm1/root/$gitlab_project_name.git" ~/gitlab/$gitlab_project_name
cd ~/gitlab/$gitlab_project_name

# Copy project files from synced folder
cp -r /vagrant/project/* .

git config --global user.email "admin@example.com"
git config --global user.name "root"
git add .
git add .gitlab-ci.yml
git commit -m "Initial commit with pipeline"
git remote add agent "http://root:$token@$vm1/root/$gitlab_project_name.git"
git push -u agent master

