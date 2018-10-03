using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using VVVV.PluginInterfaces.V2;
using SlimDX.Direct3D11;

using FeralTic.DX11;
 
namespace VVVV.DX11.Nodes
{
    [PluginInfo(Name = "Blend", Category = "DX11.RenderState",Version="Advanced MRT", Author = "vux,tonfilm")]
    public class DX11BlendStateNode : IPluginEvaluate
    {
        [Input("Render State", CheckIfChanged = true)]
        protected Pin<DX11RenderState> FInState;

        [Input("Alpha To Coverage",DefaultValue=0)]
        protected IDiffSpread<bool> FInAlphaCover;

        [Input("Enabled", DefaultValue = 0)]
        protected IDiffSpread<bool> FInEnable;

        [Input("Operation", DefaultEnumEntry = "Maximum")]
        protected IDiffSpread<BlendOperation> FInBlendOp;

        [Input("Alpha Operation", DefaultEnumEntry = "Maximum")]
        protected IDiffSpread<BlendOperation> FInBlendOpAlpha;

        [Input("Source Blend", DefaultEnumEntry = "One")]
        protected IDiffSpread<BlendOption> FInSrc;

        [Input("Source Alpha Blend", DefaultEnumEntry = "One")]
        protected IDiffSpread<BlendOption> FInSrcAlpha;

        [Input("Destination Blend", DefaultEnumEntry = "Zero")]
        protected IDiffSpread<BlendOption> FInDest;

        [Input("Destination Alpha Blend", DefaultEnumEntry = "Zero")]
        protected IDiffSpread<BlendOption> FInDestAlpha;

        [Input("Write Mask", DefaultEnumEntry = "All")]
        protected IDiffSpread<ColorWriteMaskFlags> FInWriteMask;

        [Output("Render State")]
        protected ISpread<DX11RenderState> FOutState;

        public void Evaluate(int SpreadMax)
        {
            if (this.FInAlphaCover.IsChanged
                || this.FInEnable.IsChanged
                || this.FInBlendOp.IsChanged
                || this.FInBlendOpAlpha.IsChanged
                || this.FInWriteMask.IsChanged
                || this.FInSrc.IsChanged
                || this.FInSrcAlpha.IsChanged
                || this.FInDest.IsChanged
                || this.FInDestAlpha.IsChanged)
            {
                this.FOutState.SliceCount = 1;

                DX11RenderState rs;
                if (this.FInState.PluginIO.IsConnected)
                {
                    rs = this.FInState[0].Clone();
                }
                else
                {
                    rs = new DX11RenderState();
                }
            	rs.Blend.IndependentBlendEnable = true;
				rs.Blend.AlphaToCoverageEnable = this.FInAlphaCover[0];
            	
            	for (int i = 0; i < 2; i++)
                {
                    
					
					rs.Blend.RenderTargets[i].BlendEnable = this.FInEnable[i];
					rs.Blend.RenderTargets[i].BlendOperation = this.FInBlendOp[i];
					rs.Blend.RenderTargets[i].BlendOperationAlpha = this.FInBlendOpAlpha[i];
					rs.Blend.RenderTargets[i].RenderTargetWriteMask = this.FInWriteMask[i];
					rs.Blend.RenderTargets[i].SourceBlend = this.FInSrc[i];
					rs.Blend.RenderTargets[i].SourceBlendAlpha = this.FInSrcAlpha[i];
					rs.Blend.RenderTargets[i].DestinationBlend = this.FInDest[i];
					rs.Blend.RenderTargets[i].DestinationBlendAlpha = this.FInDestAlpha[i];

                    this.FOutState[i] = rs;
                }
				
            }

        }
    }
}
