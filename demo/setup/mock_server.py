# Pelayan tiruan Supabase (Auth + PostgREST ringkas) atas Postgres tempatan, untuk ujian sahaja
import http.server, json, subprocess, urllib.parse, re, os
ROOT='/home/claude/rapid_cto'
def psql(sql,uid=None):
    pre=f"set role authenticated; select set_config('request.jwt.claim.sub','{uid}',false);" if uid else ""
    p=subprocess.run(['psql','-h','/tmp','-p','5433','-U','postgres','-d','t','-At','-v','ON_ERROR_STOP=1','-c',pre+sql] if not pre else ['psql','-h','/tmp','-p','5433','-U','postgres','-d','t','-At','-v','ON_ERROR_STOP=1','-c',pre,'-c',sql],capture_output=True,text=True)
    if p.returncode: m=re.search(r'ERROR:\s+(.*)',p.stderr); raise Exception(m.group(1) if m else p.stderr)
    out=p.stdout.strip().split('\n')
    if pre:
        i=next((k for k,l in enumerate(out) if l[:1] in '[{'),len(out)); out=out[i:]
    return '\n'.join(out)
def q(s): return "'"+str(s).replace("'","''")+"'"
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a,directory=ROOT,**k)
    def log_message(s,*a): pass
    def send(s,code,obj):
        b=json.dumps(obj).encode(); s.send_response(code); s.send_header('Content-Type','application/json'); s.end_headers(); s.wfile.write(b)
    def uid(s):
        a=s.headers.get('Authorization','');return a.replace('Bearer tok-','') if a.startswith('Bearer tok-') else None
    def do_GET(s):
        u=urllib.parse.urlparse(s.path)
        if u.path=='/demo/' or u.path=='/demo/index.html':
            h=open(ROOT+'/demo/index.html').read().replace('__SUPA_URL__','http://localhost:8767').replace('__SUPA_KEY__','mock')
            b=h.encode(); s.send_response(200); s.send_header('Content-Type','text/html'); s.end_headers(); s.wfile.write(b); return
        if u.path.startswith('/rest/v1/'):
            uid=s.uid()
            if not uid: return s.send(401,{'message':'JWT'})
            t=u.path.split('/')[-1]; qs=urllib.parse.parse_qs(u.query)
            where=[];order='';limit=''
            for k,v in qs.items():
                v=v[0]
                if k=='select':continue
                if k=='order':c,*d=v.split('.');order=f" order by {c} {'desc' if d==['desc'] else ''}";continue
                if k=='limit':limit=f' limit {int(v)}';continue
                if v.startswith('in.('):where.append(f"{k} in ({','.join(q(x) for x in v[4:-1].split(','))})")
                elif v.startswith('eq.'):where.append(f"{k}={q(v[3:])}")
            sql=f"select coalesce(json_agg(x),'[]') from (select * from public.{t}{' where '+' and '.join(where) if where else ''}{order}{limit}) x"
            try: s.send(200,json.loads(psql(sql,uid)))
            except Exception as e: s.send(400,{'message':str(e)})
            return
        return super().do_GET()
    def do_POST(s):
        u=urllib.parse.urlparse(s.path);body=json.loads(s.rfile.read(int(s.headers.get('Content-Length',0))) or b'{}')
        if u.path=='/auth/v1/token':
            g=urllib.parse.parse_qs(u.query)['grant_type'][0]
            try:
                if g=='password': uid=psql(f"select id from auth.users where email={q(body['email'])} and encrypted_password=crypt({q(body['password'])},encrypted_password)")
                else: uid=body['refresh_token'][2:]
            except Exception as e: uid=''
            if not uid: return s.send(400,{'error_description':'Invalid login credentials'})
            return s.send(200,{'access_token':'tok-'+uid,'refresh_token':'r-'+uid,'expires_in':3600,'user':{'id':uid}})
        if u.path.startswith('/rest/v1/rpc/'):
            uid=s.uid()
            if not uid: return s.send(401,{'message':'JWT'})
            fn=u.path.split('/')[-1]
            args=','.join(f"{k}=>{'NULL' if v is None else (('true' if v else 'false') if isinstance(v,bool) else q(v))}" for k,v in body.items())
            try: psql(f"select public.{fn}({args})",uid); s.send(200,None)
            except Exception as e: s.send(400,{'message':str(e)})
            return
        s.send(404,{})
http.server.ThreadingHTTPServer(('127.0.0.1',8767),H).serve_forever()
