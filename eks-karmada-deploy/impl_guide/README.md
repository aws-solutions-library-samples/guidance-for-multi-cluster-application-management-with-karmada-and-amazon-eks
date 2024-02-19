For better experience view this file as 'raw'

## Style Guide 
For writing style and formatting guidelines, refer to our [style guide](https://w.amazon.com/bin/view/WWSO-Solutions-GTM-Programs/Solutions/Style-Guide)

### Files & Folder structure

This repo is initialized with 3 required files for Implementation Guide.
* xxx_IG.md
* xxx_sidebar.yml
* xxx_images/

Do-not change the name of files or structure of this repo.

* Move all images to xxx_images/ Folder.
* File with name xxx_IG.md contains primary Implementation Guide content and file is initiated with basic structure.
* Edit the markdown file to include your content.

Every markdown file comes with following text block, replace value of *title* and *summary* according to your IG. Do-not edit other keys of this text block.
```
---
title: < title >
summary: "< summary of IG >"
published: true
sidebar: xxxxx_sidebar
permalink: xxxxxx.html
tags: document
layout: page
---

---
```
### Preview

Guidance team will share a URL to view the preview of Implementation Guide from this repo.
Preview will be updated based on commits to Main branch of this repo. Allow for upto 5-10 minutes after commit to view updates on preview URL.

The top-level sections of the Implementation Guide are:

* Overview
* Architecture overview
* Plan your deployment
* Deploy the Guidance
* Uninstall the Guidance
* Notices

## Markdown syntax

This Implementation Guide is based on markdown. We covered common markdown syntax used in our IG's.
For additional details refer to [markdown guide](https://www.markdownguide.org/basic-syntax/)

### Section headings

* Primary section heading ( avaiable in sidebar ) must start with \##
* Secondary section heading starts with \###

Example:
```
## Architecture Overview
```

### Lists

* Start every new unordered point with \-
* For ordered list start every point with specific number.
example:
```
- Point 1
- point 2
```
```
1. step 1
2. step 2
```
* To stop ordered list from resetting use {:style="counter-reset:none"}

Example:

```
5. Step 5
<image>
{:style="counter-reset:none"}
6. This step starts from number 6

```

### Text Formatting

* Bold text can be achieved by enclosing text between \** 
* Italic text can be achieved by enclosing text between  \*

Example:
```
This is inline **bold** text
```
```
This is inline *italic* text
```

### Hyper Link

To insert hyperlink within IG use following format:
```
[text_for_hyper_link](url){:target="_blank"}
```

### Images/Gif

All images/Gif used in IG must be moved to xxx_images/ folder. To insert image, use below syntax and replace image path
```
{% include image.html file="xxxxxx_images/xxxxxx.png" alt="alt text of image" %}
* Figure 1: AWS Architecture *
```
Every image must be appended with italic text containing figure number in IG and a short description.

### Code block

Code block can be included in IG by enclosing block in \``` 
You can specify the type of code to get auto color coding of the code block

For example a python code block can be written as:
```
```python
<codeblock>
\```
```

Refer [here](https://github.com/rouge-ruby/rouge/wiki/list-of-supported-languages-and-lexers) for all supported languages for code block.

### Table

Table can be included in IG using below format:
```
| **AWS service**  | Dimensions | Cost [USD] |
|-----------|------------|------------|
| Amazon API Gateway | 1,000,000 REST API calls per month  | \$ 3.50month |
| Amazon Cognito | 1,000 active users per month without advanced security feature | \$ 0.00 |
```
Every column must be seperated using | character.

### Callouts

Implementation Guide supports special callouts like Note, Important, Warning, new. Append below tag before paragraph.

```
{: .highlight }
This is highlighted text

{: .note }
This is text in note 

{: .new }
This is new text

{: .warning }
This is warning text
```
![Callout text example](/mcm_ekskarmada_images/IG-callouts.png "Callout text example")


### special characters

* Copyright symbol can be included as \&copy;
* Registered symbol can be included as \&reg;
* Trademark symbol can be included as \&trade;











