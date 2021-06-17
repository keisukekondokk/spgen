# SPGEN: Stata module to generate spatially lagged variables

The `spgen` command creates a spatially lagged variable in the dataset.

## Install

### GitHub

```
net install spgen, replace from("https://raw.githubusercontent.com/keisukekondokk/spgen/main/")
```

### SSC

```
ssc install spgen, replace
```

## Manual
See [`doc`](./doc) directory.

<pre>
.
|-- spgen.pdf //Manual
</pre>

## Demo Files
See [`demo`](./demo) directory. There are two examples.

<pre>
.
|-- columbus //Stata replication code for Anselin (1988)
|-- jpmuni_crime //Stata replication code 
</pre>

## Source Files
See [`ado`](./ado) directory. There are `spgen.ado` and `spgen.sthlp` files. 

<pre>
.
|-- spgen.ado //Stata ado file
|-- spgen.sthlp //Stata help file
</pre>	

## Terms of Use
Users (hereinafter referred to as the User or Users depending on context) of the content on this web site (hereinafter referred to as the "Content") are required to conform to the terms of use described herein (hereinafter referred to as the Terms of Use). Furthermore, use of the Content constitutes agreement by the User with the Terms of Use. The contents of the Terms of Use are subject to change without prior notice.

### Copyright
The copyright of the developed code belongs to Keisuke Kondo.

### Copyright of Third Parties
The statistical data in the demo files were taken from GeoDa on GitHub (https://geodacenter.github.io/) the Portal Site of Official Statistics of Japan, e-Stat (https://www.e-stat.go.jp/). Users must confirm their terms of use, prior to using the Content.

### Licence
The developed code is released under the MIT Licence.

### Disclaimer 
- Keisuke Kondo makes the utmost effort to maintain, but nevertheless does not guarantee, the accuracy, completeness, integrity, usability, and recency of the Content.
- Keisuke Kondo and any organization to which Keisuke Kondo belongs hereby disclaim responsibility and liability for any loss or damage that may be incurred by Users as a result of using the Content. 
- Keisuke Kondo and any organization to which Keisuke Kondo belongs are neither responsible nor liable for any loss or damage that a User of the Content may cause to any third party as a result of using the Content
The Content may be modified, moved or deleted without prior notice.

## Author
Keisuke Kondo  
Senior Fellow, Research Institute of Economy, Trade and Industry  
Email: kondo-keisuke@rieti.go.jp  
URL: https://keisukekondokk.github.io/  

## References
Anselin, Luc (1988) *Spatial Econometrics: Methods and Models*. Boston: Kluwer Academic.

Kondo, Keisuke (2015) "SPGEN: Stata module to generate spatially lagged variables" Statistical Software Components S458105, Boston College Department of Economics.  
URL: https://ideas.repec.org/c/boc/bocode/s458105.html  
