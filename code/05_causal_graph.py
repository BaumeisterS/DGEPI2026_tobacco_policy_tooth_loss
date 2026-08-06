# Causal graph (DAG + Delta-SWIG) supporting parallel trends for the tobacco DiD.
# Applies Renson, Dukes & Shahn (2026) rejection conditions + Knaus & Pfleiderer (2026) Delta-SWIG.
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Rectangle

fig, axes = plt.subplots(1, 2, figsize=(12.5, 5.6))

def node(ax, xy, label, fc="#eaf2fb", dashed=False, w=2.05, h=0.95, fs=8.0):
    x,y=xy
    ls="--" if dashed else "-"
    b=FancyBboxPatch((x-w/2,y-h/2),w,h,boxstyle="round,pad=0.03,rounding_size=0.12",
                     fc=fc,ec="black",lw=1.25,ls=ls,zorder=3)
    ax.add_patch(b); ax.text(x,y,label,ha="center",va="center",fontsize=fs,zorder=4)
    return (x,y,w,h)

def arr(ax,a,b,color="black",ls="-",rad=0.0,lw=1.5):
    p=FancyArrowPatch((a[0],a[1]),(b[0],b[1]),connectionstyle=f"arc3,rad={rad}",
        arrowstyle="-|>",mutation_scale=13,color=color,lw=lw,ls=ls,shrinkA=24,shrinkB=24,zorder=2)
    ax.add_patch(p)

# ============================ Panel A: DAG ============================
ax=axes[0]; ax.set_xlim(0,10); ax.set_ylim(0,7.3); ax.axis("off")
ax.set_title("(A) Causal DAG (two-period)", fontsize=10, loc="left")
U =node(ax,(5,6.3),"Unmeasured time-invariant\nstate factors  U", fc="#f0f0f0", dashed=True)
A =node(ax,(1.8,3.6),"Tobacco policy  A\n(tax / price / ban)", fc="#cfe8ff")
M =node(ax,(5,3.6),"Smoking  M\n(mediator)", fc="#d9f2d9")
Y1=node(ax,(8.2,3.6),"Post-period\ntooth loss  Y₁", fc="#ffe0cc")
Y0=node(ax,(1.8,1.2),"Pre-period\ntooth loss  Y₀", fc="#ffe0cc")
X =node(ax,(8.2,1.2),"Covariates  X\n(age, sex, race,\neducation, income)", fc="#fff7cc")
# confounding (handled by DiD / state + year FE)
arr(ax,U,A,color="#b03030",ls="--",rad=0.10)
arr(ax,U,Y0,color="#b03030",ls="--",rad=0.10)
arr(ax,U,Y1,color="#b03030",ls="--",rad=-0.18)
# causal pathway of interest
arr(ax,A,M,color="#1a7d1a",lw=2.0); arr(ax,M,Y1,color="#1a7d1a",lw=2.0)
# covariates
arr(ax,X,Y1,color="black",rad=0.0); arr(ax,X,Y0,color="black",rad=-0.30)
# absent edges (the three Renson conditions) -- drawn faint with X
def absent(ax,a,b,txt,rad=0.0):
    p=FancyArrowPatch((a[0],a[1]),(b[0],b[1]),connectionstyle=f"arc3,rad={rad}",
        arrowstyle="-|>",mutation_scale=11,color="#999999",lw=1.1,ls=(0,(1,1)),shrinkA=24,shrinkB=24,zorder=1)
    ax.add_patch(p)
    mx,my=(a[0]+b[0])/2,(a[1]+b[1])/2
    ax.text(mx,my,"✗",color="#cc0000",fontsize=12,ha="center",va="center",zorder=5,fontweight="bold")
absent(ax,Y0,A,"no Y0->A",rad=0.0)            # Condition 1
absent(ax,Y0,Y1,"no Y0->Y1",rad=0.30)         # Condition 3
# (explanatory text moved to the figure caption in the Supplement)

# ============================ Panel B: Delta-SWIG ============================
ax=axes[1]; ax.set_xlim(0,10); ax.set_ylim(0,7.3); ax.axis("off")
ax.set_title("(B) Δ-SWIG: conditional parallel trends", fontsize=10, loc="left")
U2=node(ax,(5,6.3),"Unmeasured time-invariant\nstate factors  U", fc="#f0f0f0", dashed=True)
# split treatment node A | a
xs,ys=1.9,3.6
b=FancyBboxPatch((xs-1.15,ys-0.5),2.3,1.0,boxstyle="round,pad=0.03,rounding_size=0.12",
                 fc="#cfe8ff",ec="black",lw=1.25,zorder=3)
ax.add_patch(b)
ax.plot([xs+0.15,xs+0.15],[ys-0.5,ys+0.5],color="black",lw=1.0,zorder=4)
ax.text(xs-0.45,ys,"A",ha="center",va="center",fontsize=9,zorder=4)
ax.text(xs+0.6,ys,"a=0",ha="center",va="center",fontsize=8.5,zorder=4)
Asw=(xs,ys,2.3,1.0); Arand=(xs-0.45,ys); Afix=(xs+0.6,ys)
dY=node(ax,(8.2,3.6),"Δ untreated tooth loss\nΔY(0) = Y₁(0) − Y₀(0)", fc="#ffe0cc", w=2.6)
X2=node(ax,(5,1.15),"Covariates  X", fc="#fff7cc", w=2.0, h=0.8)
# conditioning box around X
ax.add_patch(Rectangle((5-1.25,1.15-0.62),2.5,1.24,fill=False,ec="#1f4e79",lw=1.6,ls="--",zorder=2))
ax.text(5,0.30,"condition on X",color="#1f4e79",fontsize=8,ha="center",va="center")
# edges: U into random part of A only; U does NOT reach ΔY(0) (cancels under additive separability)
arr(ax,U2,(Arand[0],Arand[1]),color="#b03030",ls="--",rad=0.10)
arr(ax,U2,X2,color="#b03030",ls="--",rad=-0.10)
# X affects both A and ΔY(0) (the open back-door path, blocked by conditioning)
arr(ax,X2,(Arand[0],Arand[1]),color="black",rad=0.15)
arr(ax,X2,dY,color="black",rad=-0.15)
# annotation: U cancels
ax.annotate("U cancels in the\ndifference ΔY(0)\n(additive separability)",
            xy=(6.6,5.2),fontsize=7.2,ha="center",color="#b03030")
arr(ax,U2,dY,color="#b03030",ls=(0,(1,1)),rad=-0.25,lw=1.0)
mx,my=(U2[0]+dY[0])/2+0.4,(U2[1]+dY[1])/2+0.7
ax.text(mx,my,"✗",color="#cc0000",fontsize=12,ha="center",va="center",zorder=5,fontweight="bold")
# (explanatory text moved to the figure caption in the Supplement)

plt.tight_layout()
fig.savefig("output/figS_causalgraph.png", dpi=200, bbox_inches="tight")
fig.savefig("output/figS_causalgraph.tif", dpi=300, bbox_inches="tight")
print("causal graph saved")
