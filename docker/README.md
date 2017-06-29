## Docker Container with NETCONF Perl client

A small, ubuntu based, container with a working netconf client can be built from this directory with

```
make
```

Once ready, launch it and test the sample apps. The option '-v $PWD:/scripts' mounts 
optionally the current directory into the container, allowing read-write access to files.

```
$ docker images | head -2
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
netconf-perl        latest              8dca418c8bd9        6 minutes ago       298.2 MB

$ make run
docker run -ti --rm -v $PWD:/scripts --name netconf-perl netconf-perl
root@cae70c23b993:/scripts# perl /src/examples/get_system_information.pl

Options:

hostname : hostname of target router
username : A login name accepted by the target router.
password : The password for the login name

 hostname:  172.17.0.82

 username: lab

 password: lab123
 Connection established: 14410
 Server request is :
  <rpc message-id='1'>
    <get-system-information/>
  </rpc>

  Server response is:
  <rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:junos="http://xml.juniper.net/junos/16.1R3/junos" message-id='1'>
<system-information>
<hardware-model>vmx</hardware-model>
<os-name>junos</os-name>
<os-version>16.1R3.10</os-version>
<serial-number>VM586D46B4DE</serial-number>
<host-name>vmxt2</host-name>
</system-information>
</rpc-reply>


Rpc reply from server.
>>>>>>>>>>
<<<<<<<<<<

using XML::LibXMl::DOM function
inside dom object
hardware information  vmx
os-name  junos
host-name  vmxt2

using xpath
inside dom object
hardware information  vmx
os-name  junos
host-name  vmxt2
root@cae70c23b993:/src# exit
```





