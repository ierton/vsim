
module Main where

import VSim.Runtime

elab :: Elab ()
elab = do
    s1 <- alloc_signal "s1" (wconst 0) (ranged 0 5)
    s2 <- alloc_signal "s2" (wconst 0) (unranged)
    clk <- alloc_signal "clk" (wconst 0) unranged
    v <- alloc_variable "v" 0 unranged


    proc1 <- alloc_process [clk] $ do
        breakpoint
        error "bug with this us 5"
        s1  `assign` (us 5, (val clk))
        s2  `assign` (now, int 1)
        clk `assign` (now, int 1 .+. val clk)
        report "muhaha"
        return ()
 
    return ()


main = do
   sim time_max elab
