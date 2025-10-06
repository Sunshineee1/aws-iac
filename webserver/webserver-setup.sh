#!/bin/bash

sudo dnf update -y
sudo dnf install nginx -y

# Starting Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

DB_ADDRESS="$1" 
echo "<html>
<head><title> Technical interview task2</title></head>
<body>
    <h1>Success (Terraform + AWS)!</h1>
    <p>The web server works well !</p>
    <p>Database address : $DB_ADDRESS </p>
</body>
</html>" | sudo tee /usr/share/nginx/html/index.html
