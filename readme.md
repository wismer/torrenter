Torrenter
=========

A simple implementation of a BitTorrent client using the programming language ruby. As of last edit, this
version supports TCP and UDP trackers, but there is no support for scraping. The download strategy has is also not optimized 
(partly on purpose; I plan to make a ruby version of popcorn-time). This gem also supports resumption of incomplete downloads, supports multi-file
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