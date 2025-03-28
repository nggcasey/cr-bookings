Availability Logic - Done
Make Bookings - WIP

TODO:

# cr-bookings

**Status:** UNFINISHED (Currently not maintained due to a lack of time and motivation)

This is unfinished work that I don't have the time to finish. There is some basic functionality enough to give another dev a rough idea of what I was trying to accomplish if someone wants to pick up on the work, but if not I might return to this project if and when I summon the motivation.

Some parts of the UI and backend logic are functional, but full appointment management and conflict resolution are incomplete.

## About
`cr-appointments` is a FiveM resource designed for a Qbox-based server, allowing players to book appointments with businesses. Businesses can set availability, and players can view available slots and make bookings through ox_lib menus.

## Screenshots

![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077146980454471/image.png?ex=67e77d76&is=67e62bf6&hm=eb3a160c3a136b116de74b41f2393e57bba2614ed1d8c1193fd0990fe593db22&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077147286372382/image.png?ex=67e77d76&is=67e62bf6&hm=6aca1d2685ec27600998b5f143b0c37e6c2c80b5f181d0c50f0462d92d3bb41d&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077147575914606/image.png?ex=67e77d76&is=67e62bf6&hm=059e65f38b5a4038437f0507a4faf06e5d0e58bd79b61afab8a229110f5c46d1&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077147873841162/image.png?ex=67e77d76&is=67e62bf6&hm=0f96bedef2edfc92332fa867c73fcdd4c46c661c13ddbcc941cf2ed41a010cc0&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077148146204766/image.png?ex=67e77d76&is=67e62bf6&hm=7253bc34a0f987710e62f49b18234d8b536b1da8e4510d1da9d31358d88805ec&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077148410581024/image.png?ex=67e77d76&is=67e62bf6&hm=31484475823340e3927fee67d3a3917be10b0f8f90b8fe20cda9d62c791c2ef9&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077148700119102/image.png?ex=67e77d76&is=67e62bf6&hm=20347f8e546045b07ae702ec87b6d37f83b8fcd8426827e5d915ecb52b75795b&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077148980871322/image.png?ex=67e77d76&is=67e62bf6&hm=2e0ad3fd518416ee6ce59aa20619f0009bf365adf156d6ddeb73d585d1dd675c&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077149228470323/image.png?ex=67e77d76&is=67e62bf6&hm=f55d123b84857f7dbd8a1a88d5220d471d21fd31320c5ff4a71748eb76f14466&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077148146204766/image.png?ex=67e77d76&is=67e62bf6&hm=7253bc34a0f987710e62f49b18234d8b536b1da8e4510d1da9d31358d88805ec&=&format=webp&quality=lossless)
![Description of Screenshot](https://media.discordapp.net/attachments/1345077146728665280/1345077149538979981/image.png?ex=67e77d76&is=67e62bf6&hm=27c55695bef23cb21a37fe8d0a411f4631fb93461827d28d2b182de749d0e778&=&format=webp&quality=lossless&width=308&height=856)


## Features (Planned & Partially Implemented)
- **Player Side:**
  - Look up businesses and available appointment slots
  - Book appointments through an iPad-style UI (accessed via `/bookings`)
- **Business Side:**
  - Set availability, including for individual staff members
  - Manage existing availability entries
- **Backend:**
  - Uses `oxmysql` for database interactions
  - Expired availability auto-deletion (not implemented)
  - Context menu for listing existing availability

## TODO:

1. ADD SERVER SIDE CHECKS - Conflicts, rate limiting, queuing bookings, security
2. Expired availability auto-deletion from database (not implemented)
3. Heaps of other shit I can't even remember now.


## Installation (For Reference)
While unfinished, you can still install and explore the existing functionality:
1. Clone the repository into your FiveM resources folder.
2. Ensure `oxmysql` is installed and configured.
3. Add `ensure cr-bookings` to your `server.cfg`.
4. Use `/bookings` in-game to access the UI (if implemented in your version).

## Future Plans (If Development Resumes)
- Complete the booking system and appointment cancellations
- Improve conflict-checking when setting availability
- Enhance UI with better filters and search options
- Optimize for performance with large player counts

