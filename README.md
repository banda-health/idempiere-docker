# idemp-docker
![TeamCity build status](https://teamcity.bandahealth.org/app/rest/builds/buildType:id:BHGO_IdempDocker_Build/statusIcon.svg)

The Banda version of iDempiere docker to use our specific files and for testing.

## How to Use
Any files to be used by the container should be placed in the `./src` directory.
### iDempiere Installer File
An iDempiere tar file is needed to install iDempiere in the container. You can fetch this file from the BandaHealth build for iDempiere, a downloadable from the iDempiere website, or you can build one yourself. If you want to build one, do the following:
1. Navigate to your iDempiere local repository.
2. Run
```
mvn verify
```
3. Navigate to the following directory:
```
[iDempiere directory]/org.idempiere.p2/target/products/org.adempiere.server.product/linux/gtk
```
4. If on Windows, don't forget to convert the line endings by running
```
find ./ -name *.sh -exec dos2unix '{}' \;
```
5. Compress and Zip the file (you can run the following command on Linux).
```
tar -zcvf idempiere.build.gtk.linux.x86_64.tar.gz x86_64
```

Put the file in the `./idempiere`  directory and ensure it's called:
```
idempiere.build.gtk.linux.x86_64.tar.gz
```
### Initialization
#### DB Initialization
There are two choices for DB initialization:
1. iDempiere Base DB
2. A DB generated from a specified file.

To run any DB initialization, create a file called `initial-db.dmp` and put it in `./src`. It should be generated using:
```
pg_dump -Fc --file=initial-db.dmp [DATABASE NAME]
```
You can use compression with the `pg_dump` command, if you wish.

At it's default, a new DB will only be initialized if one doesn't exist. To override this (which is useful for testing purposes) set the following environment variable:
```
IDEMPIERE_FRESH_DB=true
```
#### DB Migrations
Place all migrations, both script and 2-pack, in a `./src/migration` directory (matching the structure of iDempiere's `migration` directory). Migrations will automatically be applied if no DB exists and no DB initialization script is provided when this stack is run.

If you wish DB script to be applied no matter when, you can use the environment variable:
```
MIGRATE_EXISTING_DATABASE=true
```
#### Plugins
Any plugins should go in a `./srce/plugin` directory. These will be copied into the image and run with iDempiere.

Additionally, you can optionally create a `./src/bundles.info` file matching the information at the bottom of [the iDempiere plugin installation tutorial](https://wiki.idempiere.org/en/Developing_Plug-Ins_-_Get_your_Plug-In_running). Basically, put each plugin on it's own line and follow the following format:
```
${plugin_name},${plugin_version},${plugin_file},${start_level},${auto_start}
```

If you would like a `bundles.info` file auto-generated for you, you can set the environment variable:
```
GENERATE_PLUGIN_BUNDLE_INFO=true
```

### Environment Configuration
See the `.env.default` file for examples of what should go into your own `.env` file. Some things to note are:

* If you're running this locally, you may want to change the following ports to avoid conflicts with your local setup:
	* IDEMPIERE_PORT
	* POSTGRES_PORT
	* IDEMPIERE_SSL_PORT

## Unit Testing
It is a good idea to make sure that the DB is created each time, so make use of the environment variable mentioned under [DB Initialization](#db-initialization) above.

This image will load plugins, migration scripts, and reports, so feel free to include those in testing. Additionally, you can set up the container to not return healthy until all plugins have been resolved/started by setting the following environment variable:
```
HEALTHY_AFTER_PLUGINS_START=true
```

If using a Docker compose file, you can set the following in whichever service is dependent on the iDempiere service (e.g. a service to run tests against iDempiere):
```
services:
	idempiere:
		...
	
	service_needing_idempiere:
		...
		depends_on:
			idempiere:
				condition: service_healthy
```