---
layout: article
title: Evading AV with XLM Macros / Microsoft Excel
description: A malicious Office document (Word/Excel) is one of the most common vector of attacks that is highly effective when combined with the right social engineering techniques. This is due to the versatile nature of VBA/XLM scripts which can be used for deploying malware when executed. This post will take a deep dive for the old-school Excel 4.0 macros
category: research
modified: N/A
tags: [golang, macros, evasion, office]
image:
    path: "/assets/images/xlm-macros.png"
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


<i><b>Disclaimer:</b> Usage of this application for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. I assume no liability and I am not responsible for any misuse or damage caused.</i>

<i>[Go back to homepage](../)</i>
