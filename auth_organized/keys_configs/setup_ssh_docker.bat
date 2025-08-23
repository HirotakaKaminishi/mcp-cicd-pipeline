@echo off
echo Setting up SSH key for Docker deployment...
echo.
echo Please enter the root password for 192.168.111.200 when prompted:
echo.
ssh-copy-id -i C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\mcp_docker_key.pub root@192.168.111.200
echo.
echo SSH key has been copied to server!
echo You can now connect using: ssh -i mcp_docker_key root@192.168.111.200
pause