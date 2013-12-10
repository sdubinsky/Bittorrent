417 project

Things to do:

* Parse metainfo file - DONE
* Connect to tracker - DONE
  * Get list of peers - DONE
  * Save list of peers - DONE
* Connect to a peer:
  * handshake in one thread - DONE - do we need to verify response? - yes, according to the protocol, in case it's a new peer at the same address.
  * get the frequencies for all the bitfields from our peers combined
  * get info about peers that have the most uncommon pieces - these are the ones we want to start downloading first
* Choking protocol:

  * make threads for the peers and begin the following:
		our client sends 'interested'
		they send 'unchoked'
		our clients request pieces
		...until we get a choke message from that peer
  * receive pieces
  * make sure SHA1 for each pieces is okay
  * update client's bitfield for the pieces we now have

  * we also have to worry about receiving messages for our peers and uploading to them... 

Sources:
* http://www.kristenwidman.com/blog/how-to-write-a-bittorrent-client-part-2/
* https://wiki.theory.org/BitTorrentSpecification
