1. (Relative Stability) Anchored or Pegged -> $1.00
   1. chainlink pricefeed .
   2. set a function to exchange ETH & BTC -> $$
2. (Stability Mechanism (Minting)) : Algorithmic (Decentralized)
   1. People can only mint the stablecoin with enough collateral (coded)
3. (Collateral) : Exogeneous
   1. wETH
   2. wBTC



Nenu deposit chesina Collateral - 20 ETH(erc token)
ippudu ee 20 ETH ni USD loki convert cheyadaniki Chainlink use chestaamu 


health factor kanukovadaniki:-

               1 ETh  ==  $20000 (from Chain Link )
suppose okavela 20 ETH == $ 40000

pina $40000 lo 50% tisukuntaaru %20000

ippudu ee $20000 ni manam mint chesukunna stable coins tho divide chestaaru.(each stable is equal to $1)

precesion kosam ani $20000 ki 1e18 add chestamu... appudu:- $20000 * 1e18
                                                           ----------------- < 1e18 (health factor break chesinatle )
suppose manam kani 200001 stable coin mint chesukunnam anukoo  20000(here each stable coin is greater than 0) 
_________________________________________________________________________________________________________________________________________ 20 <8


amountCollateral = 10 ether
amountToMint = 100 ether

1 eth = 2000
10 eth = 20000

health factor:- 

50% of 20000 ==> 10000 * 1e18 / 10 ether ==> 1000 * 1e18 < 



modifictaion at line 199-201 (in _burn function) 


BUG in my point of view:- 

i_dsc(DEcentralizedStableCoin.sol) == This contract keeps tracks of all the minted stable coins

IN LIQUIDATION PROCESS:-


* After Minting stable coins every time: s_DSCMinted[liquidator] is updating their balance by adding respective minted count (assume dscminted = 10 stable coins)

* In liquidation (Assume debtToCOver = 4 stablecoins), Liquidator has to transfer 4 stablecoins out of 10 stable coins fron their balance 

* But  s_DSCMinted[liquidator] is not updating balance as 6 stable coins

