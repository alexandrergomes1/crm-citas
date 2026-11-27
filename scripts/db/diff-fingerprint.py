#!/usr/bin/env python3
"""Compara duas impressões digitais (uma linha "tipo|objeto|hash" por objeto).
Uso: diff-fingerprint.py producao.txt replay.txt"""
import sys
def load(f):
  d={}
  for l in open(f):
    l=l.rstrip('\n')
    if not l: continue
    kind,k,h=l.split('|',2); d[(kind,k)]=h
  return d
P=load(sys.argv[1]);L=load(sys.argv[2])
from collections import defaultdict
out=defaultdict(list)
for key in sorted(set(P)|set(L)):
  if key not in L: out['only_prod'].append(key)
  elif key not in P: out['only_local'].append(key)
  elif P[key]!=L[key]: out['diff'].append((key,P[key],L[key]))
for k,v in out.items():
  print('==',k,len(v))
  for x in v: print('  ',x)
