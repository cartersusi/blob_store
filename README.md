Zig, no compression.
G0, zstd.

| server | route | time |
| - | - | - | 
| zig|download/books/book.pdf  |5.76|
| go|download/books/book.pdf  |6.80|
| zig|download/images/thumbnail.png  |1.04|
| go|download/images/thumbnail.png  |1.28|
| zig|download/videos/video.mov |35.84|
| go|download/videos/video.mov |40.64|
| zig|upload/books/book.pdf |10.48|
| go|upload/books/book.pdf |26.16|
| zig|upload/images/thumbnail.png  |1.36|
| go|upload/images/thumbnail.png  |4.40|
| zig|upload/videos/video.mov |74.20|
| go|upload/videos/video.mov |58.88|