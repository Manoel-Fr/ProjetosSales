 let result = [
  {
    "code": "BTC",
    "codein": "BRL",
    "name": "Bitcoin/Real Brasileiro",
    "high": "576000",
    "low": "560181",
    "varBid": "2905",
    "pctChange": "0.51",
    "bid": "573777",
    "ask": "573990",
    "timestamp": "1732536016",
    "create_date": "2024-11-25 09:00:16"
  },
  {
    "high": "576000",
    "low": "560181",
    "varBid": "1092",
    "pctChange": "0.19",
    "bid": "572806",
    "ask": "573005",
    "timestamp": "1732492761"
  },
  {
    "high": "577890",
    "low": "569490",
    "varBid": "-5728",
    "pctChange": "-0.99",
    "bid": "571255",
    "ask": "571477",
    "timestamp": "1732406339"
  },
  {
    "high": "580800",
    "low": "568000",
    "varBid": "4438",
    "pctChange": "0.78",
    "bid": "577187",
    "ask": "577386",
    "timestamp": "1732319952"
  },
  {
    "high": "575000",
    "low": "546607",
    "varBid": "26189",
    "pctChange": "4.79",
    "bid": "572941",
    "ask": "573211",
    "timestamp": "1732233562"
  },
  {
    "high": "549999",
    "low": "532280",
    "varBid": "9967",
    "pctChange": "1.86",
    "bid": "547021",
    "ask": "547021",
    "timestamp": "1732147141"
  },
  {
    "high": "543544",
    "low": "522745",
    "varBid": "13532",
    "pctChange": "2.58",
    "bid": "536924",
    "ask": "537054",
    "timestamp": "1732060768"
  }
]


    for(let i = 1; i < result.length; i++) {

     let res = result[i]
     let resultAnt = result[i - 1]

     res.pctChange = [];
       
      let bidOntem = parseFloat(resultAnt.bid)
      let bidHj = parseFloat(res.bid)
    
       let vari = ((bidHj - bidOntem) / bidOntem) * 100
 
       res.pctChange = vari;
     }
 
   

 /* for(let resultado : result) {

    resultado.pctChange = [];

 let res = result[0];
 let resAnterior = result[i - 1];

  let vari = ((res.bid - resAnterior.bid)  / resAnterior.bid) * 100;

    result.pctChange = vari

  } */


    /*
  let anterior = element.filter((el,index) => {
      return index > 0 && el.create_date < element[index - 1].create_date; } )
        
        let bidAnt = anterior[0].bid;
        let bidHj = element[element.length - 1].bid

         let vari = ((bidHj - bidAnt) / bidAnt) * 100;
              
        element.pctChange = vari ;
           
       */


    console.log(result)