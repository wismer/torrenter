Torrenter
=========




A simple implementation of a BitTorrent client in Ruby. As of last edit, this
version supports TCP and UDP trackers, but there is no support for scraping (querying web html/xml for necessary data). The download strategy follows the sequential ordering of the pieces (i.e. pieces that are selected for downloading are done in order that they appear). There is a more optimized strategy for downloading pieces that follows the "rarest" piece first, but that method would be prohibitive for doing content streaming. This gem also supports resumption of incomplete downloads, supports multi-file
torrents (like music albums) and sports a download meter in the terminal!

To start using, first install

    gem install torrenter

In the terminal, `cd` to wherever you download your torrent files and issue the following command:

    torrenter <torrentFile>

Immediately two files will be created - a file where the data gets "dumped" into (`.torrent-data`)
and the folder for where the content files will be transported to after the download finished. After 
the download completes, the files are placed into their destination folder. After that, the dumped data
file is removed. 

Sinatra Web App
-----------------
I added a simple sinatra web app as a sort of tool to better visualize the download of the torrent,
courtesy of d3.js.

![screenshot](/ss.png "Title")


TODO
---------
* Add video streaming option in sinatra app
* Remove redundant instance variables in peer class
* Reconnect to trackers on set time intervals as indicated by the tracker
* ~~~Implement "rarest first" download strategy~~~
* Write unit tests