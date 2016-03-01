//
//  AI.cpp
//  Gomoku
//
//  Created by Joshua on 15/1/4.
//  Copyright (c) 2015年 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <cstdio>
#include <cstring>
#include <queue>
#define N 15
#define MAX_DEPTH 5
#define MAX_CHAR 127
#define INF (1e301)
using namespace std;

template <typename T> inline T min_(const T &x,const T &y) { return x<y?x:y; }
template <typename T> inline T max_(const T &x,const T &y) { return x>y?x:y; }
template <typename T> inline T abs_(const T &x) { return x>0?x:-x; }


template <class Tp> struct stack{
    Tp A[N*N+1]; int num;
    stack():num(0){
        memset(A,0,sizeof(A));
    }
    
    inline Tp top(){
        return A[num];
    }
    
    inline void push(const Tp &x){
        A[++num]=x;
    }
    
    inline void pop(){
        num--;
    }
};


struct point{
    int x,y;
    inline point():x(0),y(0){}
};

struct hash_{
    double a[1<<14];
    double b[1<<12];
    double c[1<<10];
    hash_(){
        memset(a,0,sizeof(a));
        memset(b,0,sizeof(b));
        memset(c,0,sizeof(c));
        int n,s; double v;
        NSString *nodePath=[[NSBundle mainBundle] pathForResource:@"database" ofType:@"txt"];
        FILE* Fin=fopen([nodePath UTF8String],"r");
        while(fscanf(Fin,"%d %d %lf\n",&n,&s,&v)>0){
            switch(n){
                case 5:c[s]=v;break;
                case 6:b[s]=v;break;
                case 7:a[s]=v;
            }
        }
    }
};

struct Gomoku{
    int dx[4],dy[4];
    int NextX,NextY;
    point LC,RC,CT; // LC: left-down most corner, RC: right-up most corner, CT: center
    int chessboard[N][N];
    bool vis[N][N];
    double val;
    stack<double> S;
    queue<point> Q;
    point sq[N*N+1]; int sq_size;
    
    hash_ database;
    Gomoku():val(0){
        S.push(0);
        memset(chessboard,0,sizeof(chessboard));
        memset(vis,0,sizeof(vis));
        LC.x=LC.y=16; RC.x=RC.y=-1;
        dx[0]=1,dx[1]=0,dx[2]=1,dx[3]=1,dy[0]=0,dy[1]=1,dy[2]=1,dy[3]=-1;
    };
    
    struct Option{
        char A[N][N]; //A[x][y]: the depth added
        stack<int> sx,sy;
        Option(){
            memset(A,0,sizeof(A));
        }
        
        inline void add(const int &x,const int &y,const int &d,const int &depth){
            int lx=max_(0,x-d),rx=min_(N-1,x+d),ly=max_(0,y-d),ry=min_(N-1,y+d);
            for(int i=lx;i<=rx;i++)
                for(int j=ly;j<=ry;j++)
                    if(!A[i][j]){
                        A[i][j]=depth;
                        if(depth!=MAX_CHAR){
                            sx.push(i); sy.push(j);
                        }
                    }
        }
        
        inline void rollback(const int &depth){
            int x=sx.top(),y=sy.top();
            while(A[x][y]==depth){
                A[x][y]=0;
                sx.pop();sy.pop();
                x=sx.top(),y=sy.top();
            }
        }
    }opt;
    
    
    inline CGPoint myTurn(const int &x,const int &y){
        set_white(x,y,MAX_CHAR);
        change_(x,y,-1);
        updatePoints(LC,RC,CT,x,y);
        printf("After Put White at %d %d, Val: %lf\n",x,y,val);
        
        setSchSeq();
        alpha_beta(1,-INF,INF);
        set_black(NextX,NextY,MAX_CHAR);
        change_(NextX,NextY,1);
        printf("After Put Black at %d %d, Val: %lf\n",NextX,NextY,val);
        
        updatePoints(LC,RC,CT,NextX,NextY);
        return CGPointMake(NextX,NextY);
    }
    
    inline void updatePoints(point &lc,point &rc,point &ct,const int &x,const int &y){
        lc.x=min_(lc.x,x),lc.y=min_(lc.y,y);
        rc.x=max_(rc.x,x),rc.y=max_(rc.y,y);
        ct.x=(lc.x+rc.x)>>1; ct.y=(lc.y+rc.y)>>1;
    }
    
    inline void setSchSeq(){
        point u; int nx,ny; sq_size=-1;
        memset(vis,0,sizeof(vis));
        Q.push(CT);
        while(!Q.empty()){
            u=Q.front();
            Q.pop();
            for(int i=-1;i<=1;i++)
                for(int j=-1;j<=1;j++){
                    nx=u.x+i,ny=u.y+j;
                    if(0<=nx&&nx<N&&0<=ny&&ny<N&&(!vis[nx][ny])){
                        u.x=nx,u.y=ny;
                        Q.push(u);
                        sq[++sq_size]=u;
                        vis[nx][ny]=true;
                    }
                }
        }
    }
    
    inline void set_black(const int &x,const int &y,const int &depth){
        chessboard[x][y]=1;
        opt.add(x,y,2,depth);
    }
    inline void set_white(const int &x,const int &y,const int &depth){
        chessboard[x][y]=-1;
        opt.add(x,y,1,depth);
    }
    inline void set_blank(const int &x,const int &y,const int &depth){
        chessboard[x][y]=0;
        opt.rollback(depth);
    }
    
    int check;
    const int five=(0x3ff<<4),six=(0xfff<<2),seven=(0x3fff);
    double f__(const int &i ,const int &j,const int &color,const int &type){
        double ans=0;
        chessboard[i][j]=type;
        for(int k=0;k<4;k++){
            check=0;
            for(int it=-6;it<=6;it++){
                if(chessboard[i+it*dx[k]][j+it*dy[k]]==-color||max_(i+it*dx[k],j+it*dy[k])>14||min_(i+it*dx[k],j+it*dy[k])<0)check|=2;//,printf("x");
                else if(chessboard[i+it*dx[k]][j+it*dy[k]]==color) check|=1;
                check<<=2;
            }
            check>>=2;
            for(int k=0;k<=12;k+=2){
                ans+=database.a[(((seven<<k)&check)>>k)];
                if(k==12)continue;
                ans+=database.b[(((six<<k)&check)>>k)>>2];
                if(k==10)continue;
                ans+=database.c[(((five<<k)&check)>>k)>>4];
            }
        }
        return ans;
    }
    
    double change_(const int &i,const int &j,const int &color){
        double d=0,coe_b,coe_w;
        if(color==1) coe_b=1.0,coe_w=5.0;
        else if(color==-1) coe_b=5.0,coe_w=1.0;
        d+=coe_b*color*f__(i,j,color,color);
        d+=coe_w*color*(f__(i,j,-color,0)-f__(i,j,-color,color));
        val+=d;
        S.push(val);
        return d;
    }
    
    double remove_(){
        S.pop();
        val = S.top();
        return val;
    }
    
    double alpha_beta(int depth, double alpha, double beta){
        if(depth == MAX_DEPTH) return evaluate();
        if(abs_(val) > 500000000.0)
            return val;
        
        double v = depth & 1? -INF: INF;
        for (int i = 0; i < sq_size; i++)
        {
            int x = sq[i].x, y = sq[i].y;
            if (opt.A[x][y] && (!chessboard[x][y]))
            {
                if (depth & 1)
                {
                    set_black(x, y, depth);
                    change_(x, y, 1);
                    double temp = alpha;
                    v = max_(v, alpha_beta(depth + 1, alpha, beta));
                    alpha = max_(alpha, v);
                    if(depth == 1 && v > temp)
                        NextX = x, NextY = y;
                }
                else
                {
                    set_white(x, y, depth);
                    change_(x, y, -1);
                    v = min_(v, alpha_beta(depth + 1, alpha, beta));
                    beta = min_(beta, v);
                }
                remove_();
                set_blank(x, y, depth);
                if(alpha >= beta) return v;
            }
        }
        return v;
    }
    
    inline double evaluate(){
        return val;
        /*double ans=0;
        for(int i=0;i<15;i++)
            for(int j=0;j<15;j++){
                if(chessboard[i][j]<0)
                    ans+=-15*f__(i,j,-1,chessboard[i][j]);
                else
                    ans+=chessboard[i][j]*f__(i,j,1,chessboard[i][j]);
            }
        return ans;*/
    }
};