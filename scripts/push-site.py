"""Push a verified source commit; accept the ephemeral credential on hidden stdin only."""
import json,sys,os,subprocess,termios
fd=sys.stdin.fileno()
old=termios.tcgetattr(fd)
new=termios.tcgetattr(fd);new[3]&=~termios.ECHO
termios.tcsetattr(fd,termios.TCSANOW,new)
print('Ready for credential JSON on stdin (input hidden).',flush=True)
try:
 credential=json.loads(sys.stdin.readline())
finally:
 termios.tcsetattr(fd,termios.TCSANOW,old)
env=os.environ.copy()
if credential.get('token'):
 env.update({'GIT_CONFIG_COUNT':'1','GIT_CONFIG_KEY_0':'http.extraHeader','GIT_CONFIG_VALUE_0':'Authorization: Bearer '+credential['token']})
result=subprocess.run(['git','push',credential['remote_url'],'HEAD:refs/heads/'+credential['branch']],env=env,capture_output=True,text=True)
# Never print a credential or command environment.
print(json.dumps({'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr}))
sys.exit(result.returncode)
