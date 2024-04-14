from flask import Flask
import requests
from threading import Thread
from time import sleep

app = Flask(__name__)

bitcoin_values = []
price = 0

def fetch_bitcoin_price():
    global price  # Declare price as global to modify the global variable
    while True:
        response = requests.get('https://api.coindesk.com/v1/bpi/currentprice/BTC.json')
        if response:
            # Extract price and update it globally
            price_str = response.json()['bpi']['USD']['rate']
            price = float(price_str.replace(',', ''))
            bitcoin_values.append(price)
            # Maintain only the last 10 values
            if len(bitcoin_values) > 10:
                bitcoin_values.pop(0)
            print(f"Current Bitcoin value in USD: {price_str}", flush=True)
            if len(bitcoin_values) == 10:
                print(f"Average of last 10 values: {sum(bitcoin_values)/10}", flush=True)
        else:
            print("faliled to get bitcoin price from remote API")
        sleep(6)

@app.route('/')
def hello_world():
    return "Service for Bitcoin prices"

if __name__ == '__main__':
    Thread(target=fetch_bitcoin_price).start()
    app.run(host='0.0.0.0', port=5000)
