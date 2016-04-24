---
layout: post
title: RDS (MySQL) over SSL
tags: [rds]
---

The AWS-service [RDS (Relational Database Service)](https://aws.amazon.com/rds/){:target="_blank"} offers fully managed relational databases as a service. The database-types can be MySQL, PostgreSQL, MariaDB, Oracle, Mircosoft SQL-Server or Amazon Aurora. In case you never heard of Amazon Aurora, it's a database with MySQL under the hood with lots of improvements concerning performance, scalability and failover-concepts.

Unfortunately, Amazon Aurora isn't available in my home region (eu-central-1 / Frankfurt, Germany), yet. Therefore, we're using MySQL over a SSL-encrypted connection.

## Check if SSL is SSL enable on the server

In case you want to check if your MySQL-server supports SSL-encrypted connections, connect to the database and issue the command **show variables like '%ssl';**.

{% highlight sql %}
mysql> SHOW variables like '%ssl';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| have_openssl  | YES   |
| have_ssl      | YES   |
+---------------+-------+
2 rows in set (0.00 sec)
{% endhighlight %}

Your output should tell you now **have_openssl=YES** and **have_ssl=YES**.

## Using SSL

### Download SSL-certificates

Before we can connect to our MySQL-instance via SSL, a SSL-pem bundle is needed. The bundle needs to contain the region's specific intermediate, as well as the root-ca's certificate. To help you with getting the needed certificate-bundle, I wrote a small Bash-script. It takes only one parameter, which is the region.

{% highlight bash %}
#!/bin/bash

# parameters
region=$1

# variabales
intermediate_file="rds-ca-2015-${region}.pem"
intermediate_url="https://s3.amazonaws.com/rds-downloads/${intermediate_file}"
root_file="rds-ca-2015-root.pem"
root_url="https://s3.amazonaws.com/rds-downloads/${root_file}"
bundle_file="rds-ca-2015-${region}-bundle.pem"

if [[ $region == '' ]]; then
	echo "region must be specified"
	echo "usage: rds-certificate-downloader.sh eu-central-1"
	exit 1
fi

wget -q $intermediate_url
wget -q $root_url

cat $intermediate_file > $bundle_file
rm $intermediate_file

cat $root_file >> $bundle_file
rm $root_file
{% endhighlight %}

**Note:** in this example, we will create a certificate-bundle for the region eu-central-1. Therefore, the output-filename will be **rds-ca-2015-eu-central-1-bundle.pem**.

### Connect via SSL

You can test your connection to the MySQL-database without SSL the following way. You should already have access to the database. In case you can't establish a connection, please check your configuration upfront.

**Note:** the username for this example here is **db_root** and the database-name is **db_name**. You need to adjust that to your own RDS-setup upfront.

{% highlight sql %}
mysql -u db_root -p -h XYZ.XXXXXXXXXXXX.eu-central-1.rds.amazonaws.com -P 3306 db_name
{% endhighlight %}

If everything is working as expected, you get the following output in your mysql-client.

{% highlight sql %}
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 29
Server version: 5.6.27-log MySQL Community Server (GPL)

Copyright (c) 2000, 2015, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> 
{% endhighlight %}

As we want to connect via a SSL-encrypted connection, use the following command for connecting.

{% highlight sql %}
mysql -h XYZ.XXXXXXXXXXXX.eu-central-1.rds.amazonaws.com \
	-P 3306 \
	--ssl-ca=rds-ca-2015-eu-central-1-bundle.pem \
	--ssl-verify-server-cert \
	-u db_root -p db_name
{% endhighlight %}

If you're getting the same output in your mysql-client as before, you are successfully connected to your MySQL-database. To also check if your connection is encrypted, have a look at your status-output.

{% highlight sql %}
mysql> status;
--------------
mysql  Ver 14.14 Distrib 5.6.28, for debian-linux-gnu (x86_64) using  EditLine wrapper

Connection id:		33
Current database:	db_name
Current user:		db_root@XXX.XXX.XXX.XXX
SSL:			Cipher in use is AES256-SHA
Current pager:		stdout
Using outfile:		''
Using delimiter:	;
Server version:		5.6.27-log MySQL Community Server (GPL)
Protocol version:	10
Connection:		XYZ.XXXXXXXXXXXX.eu-central-1.rds.amazonaws.com via TCP/IP
Server characterset:	latin1
Db     characterset:	latin1
Client characterset:	utf8
Conn.  characterset:	utf8
TCP port:		3306
Uptime:			38 min 9 sec

Threads: 2  Questions: 11222  Slow queries: 0  Opens: 355  Flush tables: 1  Open tables: 67  Queries per second avg: 4.902
--------------
{% endhighlight %}

In the SSL-variable from the output, you should now depending on your SSL-cipher see anything **different to SSL: Not in use**.

### Enforcing SSL

When designing new services, [AWS](https://aws.amazon.com){:target="_blank"} always has a strict and sensible security-concept in mind, which is a good way of improving overall application-security. However, for RDS (MySQL), [AWS](https://aws.amazon.com){:target="_blank"} decided for the default-configuration to only enable SSL-encrypted connections, but is not enforcing its usage.

In order to enforce SSL-encrypted connections, connect to your database in an ordinary manner and issue the follwing command. Afterwards connections to the database for the specified user need to be over an SSL-encrypted connection.

**Note:** the username for this example here is **db_root**. You need to adjust that username to your RDS-setup.

**Keep your current connection to the database open and check it with a second session! If anything goes wrong, you then can still revert your changes.**

{% highlight sql %}
mysql> UPDATE mysql.user SET ssl_type='ANY' WHERE user='db_root';
mysql> FLUSH PRIVILEGES;
{% endhighlight %}