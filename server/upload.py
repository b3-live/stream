from flask import Flask,render_template,request
import re
import subprocess

app = Flask(__name__)             # create an app instance
 
@app.route('/form')
def form():
    return render_template('form.html')
 
@app.route('/upload', methods = ['POST', 'GET'])
def upload():
    if request.method == 'POST':
        f = request.files['file']
        f.save(f.filename)
        return "File saved successfully"

#$B_USERID:$B_PASS:::$B_DIR 
@app.route('/user', methods = ['POST', 'GET'])
def user():
    if request.method == 'GET':
      user_data=re.sub(r"[^a-zA-Z0-9:]", "", request.query_string.decode("utf-8"))
      print(user_data)
      if (user_data.count(':') < 2):
        return "Malformed", 400
      parts=user_data.split(":")
      create_user = subprocess.run(["create_user.sh", parts[0], parts[1], parts[2]])
      if (create_user.returncode == 0):
        return "ok", 200
      else:
        return "conflict", 409

app.run(host='localhost', port=8001)

