 let result = [
    {
      "code": "BTC",
      "codein": "BRL",
      "name": "Bitcoin/Real Brasileiro",
      "high": "570500",
      "low": "541834",
      "varBid": "25889",
      "pctChange": "4.76",
      "bid": "569000",
      "ask": "569215",
      "timestamp": "1732193382",
      "create_date": "2024-11-21 09:49:42"
    },
    {
      "alto": "549999",
      "baixo": "532280",
      "varBid": "9967",
      "pctChange": "1,86",
      "lance": "547021",
      "pedido": "547021",
      "carimbo de data/hora": "1732147141"
    },
    {
      "alto": "543544",
      "baixo": "522745",
      "varBid": "13532",
      "pctC hange": "2,58",
      "lance": "536924",
      "pedido": "537054",
      "carimbo de data/hora": "1732060768"
    },
    {
      "alto": "536500",
      "baixo": "518000",
      "varBid": "-2094",
      "pctChange": "-0,4",
      "lance": "523499",
      "pedido": "523721",
      "carimbo de data/hora": "1731974 364"
    },  ]


    let createDate = new Date(result[0].create_date);
    let anterior = result.filter((el,index) => {
        return index > 0 && el.create_date < result[index - 1].create_date;
    } )

    result.forEach(element => {
        if(element.create_date != undefined){
            return;
        }
        createDate.setDate(createDate.getDate() - 1)
       
        element.create_date = new Date(createDate);


              element.pctChange = [];

                let bidAnt = anterior.bid;
                let bidHj = element.bid

                let vari = ((bidHj - bidAnt) / bidAnt) * 100;
                 
                  element.pctChange = vari ;
    });
    console.log(result)