## ViewSwiper

The ViewSwiper allows for the swiping and revealing of views that underly a a draggable view. The most common use case for a ViewSwiper would be attaching it to a UITableViewCell or UICollectionViewCell to add custom swipe functionality for revealing additional options associated with a given row or item in a UITableView or UICollectionView.

The ViewSwiper is view-agnostic; simply conform to ViewSwipeable, define and implement the required functionality, and then customize the underlying views to your liking. The callbacks provided there as well grant you complete control over the animations and functionality of revealed views.

Copyright (c) 2017 Matthew Brown<br />
See LICENSE
