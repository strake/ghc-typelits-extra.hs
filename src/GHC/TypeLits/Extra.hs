{-|
Copyright  :  (C) 2015-2016, University of Twente,
                  2017-2018, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  Christiaan Baaij <christiaan.baaij@gmail.com>

Additional type-level operations on 'GHC.TypeLits.Nat':

  * 'Max': type-level 'max'

  * 'Min': type-level 'min'

  * 'Div': type-level 'div'

  * 'Mod': type-level 'mod'

  * 'FLog': type-level equivalent of <https://hackage.haskell.org/package/integer-gmp/docs/GHC-Integer-Logarithms.html#v:integerLogBase-35- integerLogBase#>
    .i.e. the exact integer equivalent to "@'floor' ('logBase' x y)@"

  * 'CLog': type-level equivalent of /the ceiling of/ <https://hackage.haskell.org/package/integer-gmp/docs/GHC-Integer-Logarithms.html#v:integerLogBase-35- integerLogBase#>
    .i.e. the exact integer equivalent to "@'ceiling' ('logBase' x y)@"

  * 'Log': type-level equivalent of <https://hackage.haskell.org/package/integer-gmp/docs/GHC-Integer-Logarithms.html#v:integerLogBase-35- integerLogBase#>
     where the operation only reduces when "@'floor' ('logBase' b x) ~ 'ceiling' ('logBase' b x)@"

  * 'GCD': a type-level 'gcd'

  * 'LCM': a type-level 'lcm'

A custom solver for the above operations defined is defined in
"GHC.TypeLits.Extra.Solver" as a GHC type-checker plugin. To use the plugin,
add the

@
{\-\# OPTIONS_GHC -fplugin GHC.TypeLits.Extra.Solver \#-\}
@

pragma to the header of your file.
-}

{-# LANGUAGE CPP                   #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MagicHash             #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

{-# OPTIONS_HADDOCK show-extensions #-}
{-# OPTIONS_GHC -Wno-orphans #-}

{-# LANGUAGE Trustworthy #-}

module GHC.TypeLits.Extra
  ( -- * Type-level operations on `Nat`
    -- ** Ord
    Max
  , Min
    -- ** Integral
  , Div
  , Mod
  , DivMod
    -- *** Variants
  , DivRU
    -- ** Logarithm
  , FLog
  , CLog
    -- *** Exact logarithm
  , Log
    -- Numeric
  , GCD
  , LCM
  )
where

import Data.Proxy             (Proxy (..))
import Data.Type.Bool         (If)
import GHC.Base               (Int#,isTrue#,(==#),(+#))
import GHC.Integer.Logarithms (integerLogBase#)
#if MIN_VERSION_ghc(8,2,0)
import qualified GHC.TypeNats as N
import GHC.Natural
import GHC.Prim               (int2Word#)
import GHC.TypeLits
#else
import GHC.Integer            (smallInteger)
import GHC.TypeLits           as N
#endif
  (KnownNat, Nat, type (+), type (-), type (<=), type (<=?), natVal)
#if MIN_VERSION_ghc(8,4,0)
import GHC.TypeLits           (Div, Mod)
#endif
import GHC.TypeLits.KnownNat  (KnownNat2 (..), SNatKn (..), nameToSymbol)

#if MIN_VERSION_ghc(8,2,0)
intToNumber :: Int# -> Natural
intToNumber x = NatS# (int2Word# x)
#else
intToNumber :: Int# -> Integer
intToNumber x = smallInteger x
#endif
{-# INLINE intToNumber #-}

-- | Type-level 'max'
type family Max (x :: Nat) (y :: Nat) :: Nat where
  Max n n = n
  Max x y = If (x <=? y) y x

instance (KnownNat x, KnownNat y) => KnownNat2 $(nameToSymbol ''Max) x y where
  natSing2 = SNatKn (max (N.natVal (Proxy @x)) (N.natVal (Proxy @y)))

-- | Type-level 'min'
type family Min (x :: Nat) (y :: Nat) :: Nat where
  Min n n = n
  Min x y = If (x <=? y) x y

instance (KnownNat x, KnownNat y) => KnownNat2 $(nameToSymbol ''Min) x y where
  natSing2 = SNatKn (min (N.natVal (Proxy @x)) (N.natVal (Proxy @y)))

#if !MIN_VERSION_ghc(8,4,0)
-- | Type-level 'div'
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family Div (x :: Nat) (y :: Nat) :: Nat where
  Div x 1 = x
#endif

-- | A variant of 'Div' that rounds up instead of down
type DivRU n d = Div (n + (d - 1)) d

instance (KnownNat x, KnownNat y, 1 <= y) => KnownNat2 $(nameToSymbol ''Div) x y where
  natSing2 = SNatKn (quot (N.natVal (Proxy @x)) (N.natVal (Proxy @y)))

#if !MIN_VERSION_ghc(8,4,0)
-- | Type-level 'mod'
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family Mod (x :: Nat) (y :: Nat) :: Nat where
  Mod x 1 = 0
#endif

instance (KnownNat x, KnownNat y, 1 <= y) => KnownNat2 $(nameToSymbol ''Mod) x y where
  natSing2 = SNatKn (rem (N.natVal (Proxy @x)) (N.natVal (Proxy @y)))

-- | Type-level `divMod`
type DivMod n d = '(Div n d, Mod n d)

-- | Type-level equivalent of <https://hackage.haskell.org/package/integer-gmp/docs/GHC-Integer-Logarithms.html#v:integerLogBase-35- integerLogBase#>
-- .i.e. the exact integer equivalent to "@'floor' ('logBase' x y)@"
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family FLog (x :: Nat) (y :: Nat) :: Nat where
  FLog 2 1 = 0 -- Additional equations are provided by the custom solver

instance (KnownNat x, KnownNat y, 2 <= x, 1 <= y) => KnownNat2 $(nameToSymbol ''FLog) x y where
#if MIN_VERSION_ghc (8,2,0)
  natSing2 = SNatKn (intToNumber (integerLogBase# (natVal (Proxy @x)) (natVal (Proxy @y))))
#else
  natSing2 = SNatKn (intToNumber (integerLogBase# (natVal (Proxy @x)) (natVal (Proxy @y))))
#endif

-- | Type-level equivalent of /the ceiling of/ <https://hackage.haskell.org/package/integer-gmp/docs/GHC-Integer-Logarithms.html#v:integerLogBase-35- integerLogBase#>
-- .i.e. the exact integer equivalent to "@'ceiling' ('logBase' x y)@"
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family CLog (x :: Nat) (y :: Nat) :: Nat where
  CLog 2 1 = 0 -- Additional equations are provided by the custom solver

instance (KnownNat x, KnownNat y, 2 <= x, 1 <= y) => KnownNat2 $(nameToSymbol ''CLog) x y where
  natSing2 = let x  = natVal (Proxy @x)
                 y  = natVal (Proxy @y)
                 z1 = integerLogBase# x y
                 z2 = integerLogBase# x (y-1)
             in  case y of
                    1 -> SNatKn 0
                    _ | isTrue# (z1 ==# z2) -> SNatKn (intToNumber (z1 +# 1#))
                      | otherwise           -> SNatKn (intToNumber z1)

-- | Type-level equivalent of <https://hackage.haskell.org/package/integer-gmp/docs/GHC-Integer-Logarithms.html#v:integerLogBase-35- integerLogBase#>
-- where the operation only reduces when:
--
-- @
-- 'FLog' b x ~ 'CLog' b x
-- @
--
-- Additionally, the following property holds for 'Log':
--
-- > (b ^ (Log b x)) ~ x
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family Log (x :: Nat) (y :: Nat) :: Nat where
  Log 2 1 = 0 -- Additional equations are provided by the custom solver

instance (KnownNat x, KnownNat y, FLog x y ~ CLog x y) => KnownNat2 $(nameToSymbol ''Log) x y where
  natSing2 = SNatKn (intToNumber (integerLogBase# (natVal (Proxy @x)) (natVal (Proxy @y))))

-- | Type-level greatest common denominator (GCD).
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family GCD (x :: Nat) (y :: Nat) :: Nat where
  GCD 0 x = x
  GCD x 0 = x
  GCD 1 x = 1
  GCD x 1 = 1
  GCD x x = x
  -- Additional equations are provided by the custom solver

instance (KnownNat x, KnownNat y) => KnownNat2 $(nameToSymbol ''GCD) x y where
  natSing2 = SNatKn (gcd (N.natVal (Proxy @x)) (N.natVal (Proxy @y)))

-- | Type-level least common multiple (LCM).
--
-- Note that additional equations are provided by the type-checker plugin solver
-- "GHC.TypeLits.Extra.Solver".
type family LCM (x :: Nat) (y :: Nat) :: Nat where
  LCM 0 x = 0
  LCM x 0 = 0
  LCM 1 x = x
  LCM x 1 = x
  LCM x x = x
  -- Additional equations are provided by the custom solver

instance (KnownNat x, KnownNat y) => KnownNat2 $(nameToSymbol ''LCM) x y where
  natSing2 = SNatKn (lcm (N.natVal (Proxy @x)) (N.natVal (Proxy @y)))
