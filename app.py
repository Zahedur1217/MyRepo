from flask import Flask
app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Welcome to Docker, CI/CD with AWS CodeDeploy!</h1>"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)


