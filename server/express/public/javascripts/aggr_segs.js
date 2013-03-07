

function NdnProtocol() {
    this.ndn = new NDN({ getTransport: function() { return new XpcomTransport(); }, 
                       verify: false });
}

NdnProtocol.prototype = {
    scheme: "ndn",
    protocolFlags: nsIProtocolHandler.URI_NORELATIVE |
                   nsIProtocolHandler.URI_NOAUTH |
                   nsIProtocolHandler.URI_LOADABLE_BY_ANYONE,

    newURI: function(aSpec, aOriginCharset, aBaseURI)
    {
        var uri = Cc["@mozilla.org/network/simple-uri;1"].createInstance(Ci.nsIURI);

        // We have to trim now because nsIURI converts spaces to %20 and we can't trim in newChannel.
        var uriParts = NdnProtocolInfo.splitUri(aSpec);
        if (aBaseURI == null || uriParts.name.length < 1 || uriParts.name[0] == '/')
            // Just reconstruct the trimmed URI.
            uri.spec = "ndn:" + uriParts.name + uriParts.search + uriParts.hash;
        else {
            // Make a URI relative to the base name up to the file name component.
            var baseUriParts = NdnProtocolInfo.splitUri(aBaseURI.spec);
            var baseName = new Name(baseUriParts.name);
            var iFileName = baseName.indexOfFileName();
            
            var relativeName = uriParts.name;
            // Handle ../
            while (true) {
                if (relativeName.substr(0, 2) == "./")
                    relativeName = relativeName.substr(2);
                else if (relativeName.substr(0, 3) == "../") {
                    relativeName = relativeName.substr(3);
                    if (iFileName > 0)
                        --iFileName;
                }
                else
                    break;
            }
            
            var prefixUri = "/";
            if (iFileName > 0)
                prefixUri = new Name(baseName.components.slice(0, iFileName)).to_uri() + "/";
            uri.spec = "ndn:" + prefixUri + relativeName + uriParts.search + uriParts.hash;
        }
        
        return uri;
    },

    newChannel: function(aURI)
    {
        var thisNdnProtocol = this;
        
        try {            
            var uriParts = NdnProtocolInfo.splitUri(aURI.spec);
    
            var template = new Interest(new Name([]));
            // Use the same default as NDN.expressInterest.
            template.interestLifetime = 4000; // milliseconds
            var searchWithoutNdn = extractNdnSearch(uriParts.search, template);
            
            var segmentTemplate = new Interest(new Name([]));
            // Only use the interest selectors which make sense for fetching further segments.
            segmentTemplate.publisherPublicKeyDigest = template.publisherPublicKeyDigest;
            segmentTemplate.scope = template.scope;
            segmentTemplate.interestLifetime = template.interestLifetime;
    
            var requestContent = function(contentListener) {                
                var name = new Name(uriParts.name);
                // Use the same NDN object each time.
                thisNdnProtocol.ndn.expressInterest(name, new ExponentialReExpressClosure 
                    (new ContentClosure(thisNdnProtocol.ndn, contentListener, name, 
                            aURI, searchWithoutNdn + uriParts.hash, segmentTemplate)),
                    template);
            };

            return new ContentChannel(aURI, requestContent);
        } catch (ex) {
            dump("NdnProtocol.newChannel exception: " + ex + "\n" + ex.stack);
        }
    },

    classDescription: "ndn Protocol Handler",
    contractID: "@mozilla.org/network/protocol;1?name=" + "ndn",
    classID: Components.ID('{8122e660-1012-11e2-892e-0800200c9a66}'),
    QueryInterface: XPCOMUtils.generateQI([Ci.nsIProtocolHandler])
};
