# vps-deploy utilities

# Table of Contents
- [Deploy a new Postgres VPS](#deploy-a-new-postgres-vps)
- [Deploy a new Node.js VPS](#deploy-a-new-nodejs-vps)
- [Node.js app auto-deployment](#nodejs-app-auto-deployment)
- [Commands](#commands)

---

## Deploy a new Postgres VPS
1. Create an ssh key pair on local machine with `ssh-keygen -t ed255519 -f ~/.ssh/[MY_KEY_NAME] -P "" -C "some comment"`
2. Copy ssh PUBLIC key with `cat ~/.ssh/[MY_KEY_NAME].pub | pbcopy` and add it to Hetzner > Security > SSH Keys
3. Create new server on Hetzner with desired specs, assign the created key and paste the contents of `pg-cloud-config.yml` into the "User data" section
4. Wait for server to build and give it time to run the cloud-config. Server will reboot.
5. Connect to server with `ssh vnlf@SERVER_IP -i ~/.ssh/[MY_KEY_NAME]`

---

## Deploy a new Node.js VPS
1. Create an ssh key pair on local machine with `ssh-keygen -t ed255519 -f ~/.ssh/[MY_KEY_NAME] -P "" -C "some comment"`
2. Copy ssh PUBLIC key with `cat ~/.ssh/[MY_KEY_NAME].pub | pbcopy` and add it to Hetzner > Security > SSH Keys
3. Create new server on Hetzner with desired specs, assign the created key and paste the contents of `node-cloud-config.yml` into the "User data" section
4. Wait for server to build and give it time to run the cloud-config. Server will reboot.
5. Connect to server with `ssh vnlf@SERVER_IP -i ~/.ssh/[MY_KEY_NAME]`

---

## Node.js app auto-deployment
1. Copy the folder `./node-app-deploy/` as `_deploy` at the root of your repository
2. Move the folder `.github` out of `_deploy` to the root of your repository
3. Move the folder `scripts` out of `_deploy` to the root of your repository
4. Add the necessary package.json scripts for the deployment:
   - `build`: `bash ./scripts/build.sh` Called by `server_build.sh` to build the app for production.
     - if you need to run database migrations, do it here
   - `start`: `node ./build/server.js` Called by pm2 to run the app on the server.
5. Add secrets to the repository:
   - `SSH_PRIVATE_KEY`: The private key to use for the deployment.
   - `SSH_USER`: The user to use for the deployment.
   - `SERVER_IP`: The IP address of the deployment server.
   - `DOMAIN`: The domain name of the deployment server.
   - `ENV_FILE`: Additional environment variables to pass to the app.
6. On git push, the workflow will run and deploy the app to the server.

Files purposes:
- `init.sh`: initialization file for the deployment, called by the github actions workflow.
- `server_build.sh`: server build file for the deployment, called by `init.sh` and runs on the server.
- `utils.sh`: helper functions for the deployment.

---

## Commands

- Copy ssh key to clipboard `cat ~/.ssh/KEY_NAME.pub | pbcopy`
- Generate new ssh key `ssh-keygen -t ed255519 -C "some comment"`
- Connect to server `ssh -i ~/.ssh/KEY_NAME user@SERVER_IP`
- Connect to docker container `docker compose exec -it DOCKER_SERVICE_NAME /bin/bash`
- Connect to postgres cli `sudo -i -u postgres psql -c "..."`
- Set contents of file `echo "contents" > file.txt`
- Append line to file `echo "line" >> file.txt`
- dump pg database `sudo -u postgres pg_dump -d DB_NAME > DB_NAME.sql`


## Cloud-config

https://community.hetzner.com/tutorials/add-ssh-key-to-your-hetzner-cloud
https://community.hetzner.com/tutorials/basic-cloud-config
https://www.digitalocean.com/community/tutorials/how-to-use-cloud-config-for-your-initial-server-setup
https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu
https://cloudinit.readthedocs.io/en/latest/reference/examples.html
https://bobswinkels.com/posts/hetzner-cloud-config/
https://github.com/tech-otaku/hetzner-cloud-init/blob/main/config.yaml
https://www.inmotionhosting.com/support/product-guides/vps-hosting/ways-to-harden-your-vps-hosting/#disable-root
https://www.eurovps.com/blog/20-ways-to-secure-linux-vps/

## Postgres

https://www.databasemart.com/blog/how-to-install-postgresql-on-ubuntu-20-04-lts
https://www.digitalocean.com/community/tutorials/how-to-install-postgresql-on-ubuntu-20-04-quickstart
https://dev.to/nietzscheson/multiples-postgres-databases-in-one-service-with-docker-compose-4fdf
https://www.digitalocean.com/community/tutorials/how-to-backup-postgresql-databases-on-an-ubuntu-vps
https://tembo.io/docs/getting-started/postgres_guides/how-to-backup-and-restore-a-postgres-database


## Nginx / Node.js
https://sanghmitra-rathore.medium.com/setup-nodejs-application-server-on-aws-ec2-ubuntu-nginx-41a412d00fc3
https://blog.zysk.tech/deploying-a-nodejs-application-on-aws-ec2-with-nginx-and-ssl/
https://dev.to/shadid12/how-to-deploy-your-node-js-app-on-aws-with-nginx-and-ssl-3p5l
