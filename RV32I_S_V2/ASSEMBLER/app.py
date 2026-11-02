# pip install flask pyserial
# run: python app.py   -> open http://127.0.0.1:5000
from flask import Flask, request, jsonify, send_from_directory
import serial
import serial.tools.list_ports

app = Flask(__name__)


@app.route("/")
def index():
    return send_from_directory(".", "index.html")


@app.route("/ports")
def ports():
    return jsonify([p.device for p in serial.tools.list_ports.comports()])


@app.route("/send", methods=["POST"])
def send():
    d = request.get_json()
    port = d["port"]
    baud = int(d.get("baud", 115200))
    data = bytes(d["bytes"])  # list of ints 0-255
    try:
        with serial.Serial(port, baud, timeout=1) as s:
            s.write(data)
            s.flush()
        return jsonify(ok=True, sent=len(data))
    except Exception as e:
        return jsonify(ok=False, error=str(e)), 500


if __name__ == "__main__":
    app.run(debug=False)