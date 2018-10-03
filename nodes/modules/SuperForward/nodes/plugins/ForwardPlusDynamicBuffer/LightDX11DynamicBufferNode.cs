using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Runtime.InteropServices;
using SlimDX;
using VVVV.DX11.Nodes; 
using VVVV.PluginInterfaces.V2;
 
namespace VVVV.Nodes.DX11
{
    [StructLayout(LayoutKind.Sequential)]
    public struct Light
    { 
    	public Vector4  PositionWS;
    	
    	public Vector4  DirectionWS;
    	
    	public Vector4  PositionVS;
    	
    	public Vector4  DirectionVS;
    	
    	public Vector4  Color;
    	
    	public float    SpotlightAngle;
    	public float    Range;
    	public float    Intensity;
    	public uint		Type;
    }; 

    [PluginInfo(Name = "DynamicBuffer", Category = "DX11", Version = "ForwardPlus Light", Author = "kopffarben")]
    public class LightBuffer : VVVV.DX11.Nodes.DynamicArrayBuffer< VVVV.Nodes.DX11.Light>
    {
        [Input("View", AutoValidate = false)]
        protected Pin<Matrix> FView;

        [Input("Position", AutoValidate = false)]
        protected ISpread<Vector3> FPosition;

        [Input("Direction", AutoValidate = false)]
        protected ISpread<Vector3> FDirection;
    	
		[Input("Color", AutoValidate = false)]
        protected ISpread<Color4> FColor;
    	
        [Input("SpotlightAngle", AutoValidate = false, DefaultValue =10)]
        protected ISpread<float> FSpotlightAngle;
    	
    	[Input("Range", AutoValidate = false, DefaultValue =1)]
        protected ISpread<float> FRange;
    	
    	[Input("Intensity", AutoValidate = false, DefaultValue =1)]
        protected ISpread<float> FIntensity;
    	
    	[Input("Enabled", AutoValidate = false)]
        protected ISpread<bool> FEnabled;
    	
    	[Input("Selected", AutoValidate = false)]
        protected ISpread<bool> FSelected;
    	
    	[Input("Type", AutoValidate = false, DefaultValue =0)]
        protected ISpread<uint> FType;

        [Output("PosVS")]
		public ISpread<Vector4> FPosVS;


        protected override void BuildBuffer(int count, Light[] buffer)
        {
            this.FView.Sync();
            this.FPosition.Sync();
            this.FDirection.Sync();
            this.FColor.Sync();
        	
            this.FSpotlightAngle.Sync();
        	this.FRange.Sync();
        	this.FIntensity.Sync();
        	this.FType.Sync();
        	//this.FPosVS.SliceCount = count;

            for (int i = 0; i < count; i++)
            {
				buffer[i].PositionVS = Vector4.Transform(new Vector4(this.FPosition[i],1), this.FView[0]);
				buffer[i].PositionWS = new Vector4(this.FPosition[i],1);
             	this.FPosVS[i] = buffer[i].PositionVS;
            	
            	buffer[i].DirectionVS = Vector4.Transform(new Vector4(this.FDirection[i],1), this.FView[0]);
				buffer[i].DirectionWS = new Vector4(this.FDirection[i],1);

                buffer[i].Color = this.FColor[i].ToVector4();
            	
            	buffer[i].SpotlightAngle = this.FSpotlightAngle[i];
            	buffer[i].Range = this.FRange[i];
            	buffer[i].Intensity = this.FIntensity[i];
            	buffer[i].Type = this.FType[i];
            }
        }
    }
}
