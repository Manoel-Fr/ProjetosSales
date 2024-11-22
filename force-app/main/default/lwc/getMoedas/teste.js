 let result = [
  {
    "code": "BTC",
    "codein": "BRL",
    "name": "Bitcoin/Real Brasileiro",
    "high": "578000",
    "low": "557127",
    "varBid": "3791",
    "pctChange": "0.67",
    "bid": "570977",
    "ask": "571245",
    "timestamp": "1732285660",
    "create_date": "2024-11-22 11:27:40"
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
  },
  {
    "high": "536500",
    "low": "518000",
    "varBid": "-2094",
    "pctChange": "-0.4",
    "bid": "523499",
    "ask": "523721",
    "timestamp": "1731974364"
  },
  {
    "high": "534005",
    "low": "519786",
    "varBid": "-3519",
    "pctChange": "-0.67",
    "bid": "525686",
    "ask": "525996",
    "timestamp": "1731887946"
  },
  {
    "high": "535000",
    "low": "526270",
    "varBid": "334",
    "pctChange": "0.06",
    "bid": "529270",
    "ask": "529468",
    "timestamp": "1731801548"
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
      
    let createDate = new Date(result[0].create_date);
    result.forEach(element => {
        if(element.create_date != undefined){
            return;
        }
        createDate.setDate(createDate.getDate() - 1)
       
        element.create_date = new Date(createDate);
           
    });

 
   

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