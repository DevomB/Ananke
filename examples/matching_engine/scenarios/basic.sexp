((name basic)
 (domain matching_engine)
 (rng_seed 42)
 (commands
  ((Place_order Bid 100 10)
   (Place_order Ask 105 5)
   (Place_order Ask 99 4)
   Match
   (Place_order Bid 102 3)
   (Cancel_order 1)
   Match)))
