This is the prototype build of CCNx Federated Wiki. If you are using chrome 25+, you can test drive the prototype at leela.rosewiki.org

CCNx Federated Wiki Goals
==========================

CCNx Federated Wiki is a port of Ward Cunninghams Smallest Federated Wiki, modified to federate via Content Centric Networking via NDN-js. The concept has proven to be workable, though it will be some time before it is useable. This is the first of many projects envisioned to run over Nei.ghbor.Net, a cooperatively administered, globaly scaled, locally-focused CCN network...

We imagine two components:

1. a razor thin server serving the client code and managing a TCP websocket proxy to either a local or remote CCN router
2. a client component that renders, saves and serves pages in a users IndexedDB capable browser.

This project should be judged by the degree that it can:

* Demonstrate the versatility and practicality of distributed CCNx web applications.
* Explore federation policies necessary to sustain an open creative community.

This project is an evolution of Smallest Federated Wiki, married with NDN-js from the UCLA Named Data Team, and achieves federation via CCNx routers.

* http://github.com/WardCunningham/Smallest-Federated-Wiki
* http://github.com/named-data/NDN-js
* http://ccnx.org

How to Participate
==================

First you will want to get familiar with the projects listed above. There are numerous demo videos of SFW available. Watch them. They're short:

* http://wardcunningham.github.com

CFW retains as much of the frontend UI from SFW as possible, so you may want to read through the end-user how-to documentation for that project, which is itself written in a federated wiki:

* http://fed.wiki.org/how-to-wiki.html

Code contributions are always welcome. We're developing using the `fork and pull request` model supported so well by GitHub. Please read through their excellent help to make sure you know what's expected of you:

* http://help.github.com/send-pull-requests/

If you'd like to know what we think of your programming idea before you program it, just write up an Issue here on GitHub. You'll save us all some time if you read through open issues first:

* [Open Issues](https://github.com/rynomad/SFCCW2/issues?sort=created&direction=desc&state=open&page=1)

We're proud to be forked frequently. Go ahead and fork this project now. We're glad to have you.


Install and Launch
==================


In order to run the server in it's current state, you'll need a local CCN daemon running. This is not a strict requirement of NDN-js, but rather of our implimentation. The server is only tested thus far on Ubuntu 12.04 LTS.

* https://www.ccnx.org/software-download-information-request/download-releases/
* http://blog.rungeek.com/post/1711470902/project-ccnx-how-to

The project is distributed as a GitHub repository. You will need a git client. Learn more from GitHub:

* http://help.github.com/

When you have git. Use it to clone the repository:

	git clone git://github.com/rynomad/SFCCW2.git

start your ccn daemon and repository. take the Welcome Visitors page from the default data folder and put it in your repository under the prefix /NeighborNet/pages/welcome-visitors (you are free to use another prefix, but note that as of now this is how the server will request your page, so you must change the client side code accordingly) Now start your server.

	cd SFCCW2/server/express
	node ./bin/server.js

And point your browser like so:

	http://localhost:3000

License
=======

CCW is an amalgom of multiple open source projects. SFW is licenced under either the MIT or GNU GPL:
[MIT License](https://github.com/WardCunningham/Smallest-Federated-Wiki/blob/master/mit-license.txt) or the
[GNU General Public License](https://github.com/WardCunningham/Smallest-Federated-Wiki/blob/master/gpl-license.txt) (GPL) Version 2.

NDN-js is licensed under a BSD style license
[NDN Licensing](https://github.com/named-data/ndn-js/blob/master/COPYING)



