function New-RssItem
{
    <#
    .Synopsis
        Creates a new RSS Feed Item
    .Description
        Creates a new RSS Feed Item.  When use with Out-Feed, can easily publish any information as RSS
    .Example
        New-RssItem -Title 'My Post' -Description 'Things I Learning While Writing Pipeworks' -Author $env:UserName -Link '.' -Category Stuff, OtherStuff
    .Link
        Out-RssFeed        
    #>
    [OutputType([string])]
    param(    
    # The post title
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$Title,
    # The post description
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias('ArticleBody', 'Html')]
    [string]$Description,
    # The post link
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]    
    [Alias('Url')]
    [Uri]$Link,
    # The author of the post
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias('Creator')]
    [string]$Author,
    # Then the post was published
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('pubDate')]
    [DateTime]$DatePublished = [DateTime]::UtcNow,
    # Categories for the post 
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('Keyword', 'Keywords', 'Tags')]
    [string[]]$Category,
    
    # If set, returns the RSS item as HTML with microdata
    [Switch]$AsHTML    
    )
    
    begin {
        Add-Type -AssemblyName System.Web
    }
    
    process {
        
        #region Collect the Categories
        $category = $category -split "\|"
        $categoryChunk = foreach ($c in $category) {
            if (-not $c) { continue }
            "<category>$([Security.SecurityElement]::Escape($c))</category>"
        }
        #endregion

        #region Create the XML                
        $rssXml = @"
<item>
    <title>$([Security.SecurityElement]::Escape($title))</title>
    <creator>$([Security.SecurityElement]::Escape($Author))</creator>
    <pubDate>$($DatePublished.ToString('r'))</pubDate>
    <description>
    <![CDATA[
    $description
    ]]>
    </description>
    <link>$([Security.SecurityElement]::Escape($link))</link>
    $categoryChunk 
</item>
"@      

        if (-not ($rssXml -as [xml])) {
        $rssXml = @"
<item>
    <title>$([Security.SecurityElement]::Escape($title))</title>
    <creator>$([Security.SecurityElement]::Escape($Author))</creator>
    <pubDate>$($DatePublished.ToString('r'))</pubDate>
    <description>
     
    </description>
    <link>$([Security.SecurityElement]::Escape($link))</link>
    $categoryChunk 
</item>
"@      

        $rssXml = [xml]$rssXml
        } else {
            $rssXml = [xml]$rssXml
        }
        #endregion Create the XML                
        
        

        # If no rssXMl exists, an exception from converting the XML should have bubbled up, so return.
        if (-not $rssXml) { return } 
        
        if ($AsHtml) {
            $pageContent = $psBoundParameters
$cats = foreach ($cat in $pageContent.Category) {
    if (-not $cat) { continue } 
    $catLink = $cat.Replace("|", " ").Replace("/", "-").Replace("\","-").Replace(":","-").Replace("!", "-").Replace(";", "-").Replace(" ", "_").Replace("@","at").Replace(",", "_") + ".posts.html"
    " <a class='relatedTagButton' href='$catLink'>
        <span itemprop='keywords' font-size='x-small'>$cat</span>
    </a>"
}                                                        
            @"
    <h2 class='ui-widget-header'><a href='$($pageContent.Link)'>$($pageContent.Title)</a></h2>       
    <meta itemprop='name' style='display:none' content='$([Web.HttpUtility]::HtmlAttributeEncode($pageContent.Title))' />
    <meta itemprop='url' style='display:none' content='$([Web.HttpUtility]::HtmlAttributeEncode($pageContent.Link))' />
    $(if ($cats) { 'More' + ($cats -join ' | ') })
    <p style='text-align:right'>                    
        <span itemprop='datePublished' style='font-size:small'/>$(([DateTime]$pageContent.DatePublished).ToLongDateString())</span><br/>   
        <a href='$moduleRssName.xml'><img src='rss.png' border='0'/></a> | $(Write-Link 'facebook:share', 'twitter:tweet'   -Horizontal )
        <meta itemprop='author' style='display:none' content='$([Web.HttpUtility]::HtmlAttributeEncode($pageContent.Author))' />
    </p>
    <div itemprop='ArticleBody'>
    $Description
    </div>           
    $(if ($pipeworksManifest.Blog.DisqusId) { Write-Link "disqus:$($pipeworksManifest.Blog.DisqusId)" })
"@            
        
        } else {
        
            #region Save it as balanced tags and chop off the xml declaration
            $strWrite = New-Object IO.StringWriter
            $rssXml.Save($strWrite)
            $prettyXml = "$strWrite"
            $prettyXml.Substring($prettyXml.IndexOf(">") + 3)        
            #endregion Save it as balanced tags and chop off the xml declaration
        }
    }
}