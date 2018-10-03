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
    public struct Material
    { 
    	public Vector4  GlobalAmbient;
    	//-------------------------- ( 16 bytes )
    	public Vector4  AmbientColor;
    	//-------------------------- ( 16 bytes )
    	public Vector4  EmissiveColor;
    	//-------------------------- ( 16 bytes )
    	public Vector4  DiffuseColor;
    	//-------------------------- ( 16 bytes )
    	public Vector4  SpecularColor;
    	//-------------------------- ( 16 bytes )
    	public Vector4  Reflectance;
    	//-------------------------- ( 16 bytes )
    	public float    Opacity;
    	public float    SpecularPower;
    	public float    IndexOfRefraction;
    	public int		HasAmbientTexture;
    	//-------------------------- ( 16 bytes )
    	public int		HasEmissiveTexture;
    	public int		HasDiffuseTexture;
    	public int		HasSpecularTexture;
    	public int		HasSpecularPowerTexture;
    	//-------------------------- ( 16 bytes )
    	public int		HasNormalTexture;
    	public int		HasBumpTexture;
    	public int		HasOpacityTexture;
    	public float	BumpIntensity;
    	//-------------------------- ( 16 bytes )
    	public float 	SpecularScale;
    	public float 	AlphaThreshold;
    	public Vector2	Padding;
    	//-------------------------- ( 16 bytes )
    };  //-------------------------- ( 16 * 10 = 160 bytes )

    [PluginInfo(Name = "DynamicBuffer", Category = "DX11", Version = "ForwardPlus Material", Author = "kopffarbens")]
    public class MaterialBuffer : VVVV.DX11.Nodes.DynamicArrayBuffer< VVVV.Nodes.DX11.Material>
    { 
        [Input("GlobalAmbient", AutoValidate = false)]
        protected ISpread<Color4> FGlobalAmbient;
		
    	[Input("AmbientColor", AutoValidate = false)]
        protected ISpread<Color4> FAmbientColor;

		[Input("EmissiveColor", AutoValidate = false)]
        protected ISpread<Color4> FEmissiveColor;
    	
    	[Input("DiffuseColor", AutoValidate = false)]
        protected ISpread<Color4> FDiffuseColor;
    	
    	[Input("SpecularColor", AutoValidate = false)]
        protected ISpread<Color4> FSpecularColor;
    	
    	[Input("Reflectance", AutoValidate = false)]
        protected ISpread<Color4> FReflectance;
        
    	[Input("Opacity", AutoValidate = false)]
        protected ISpread<float> FOpacity;
    	
    	[Input("SpecularPower", AutoValidate = false)]
        protected ISpread<float> FSpecularPower;
    	
    	[Input("IndexOfRefraction", AutoValidate = false)]
        protected ISpread<float> FIndexOfRefraction;
    	
    	[Input("HasAmbientTexture", AutoValidate = false)]
        protected ISpread<bool> FHasAmbientTexture;
    	
    	[Input("HasEmissiveTexture", AutoValidate = false)]
        protected ISpread<bool> FHasEmissiveTexture;
    	
    	[Input("HasDiffuseTexture", AutoValidate = false)]
        protected ISpread<bool> FHasDiffuseTexture;
    	
    	[Input("HasSpecularTexture", AutoValidate = false)]
        protected ISpread<bool> FHasSpecularTexture;
    	
    	[Input("HasSpecularPowerTexture", AutoValidate = false)]
        protected ISpread<bool> FHasSpecularPowerTexture;
    	
    	[Input("HasNormalTexture", AutoValidate = false)]
        protected ISpread<bool> FHasNormalTexture;
    	
    	[Input("HasBumpTexture", AutoValidate = false)]
        protected ISpread<bool> FHasBumpTexture;
    	
    	[Input("HasOpacityTexture", AutoValidate = false)]
        protected ISpread<bool> FHasOpacityTexture;
    	
    	[Input("BumpIntensity", AutoValidate = false)]
        protected ISpread<float> FBumpIntensity;
    	
    	[Input("SpecularScale", AutoValidate = false)]
        protected ISpread<float> FSpecularScale;
    	
    	[Input("AlphaThreshold", AutoValidate = false)]
        protected ISpread<float> FAlphaThreshold;


        protected override void BuildBuffer(int count, Material[] buffer)
        {
            this.FGlobalAmbient.Sync();
            this.FAmbientColor.Sync();
        	this.FEmissiveColor.Sync();
        	this.FDiffuseColor.Sync();
        	this.FSpecularColor.Sync();
        	this.FReflectance.Sync();
        	this.FOpacity.Sync();
        	this.FSpecularPower.Sync();
        	this.FHasAmbientTexture.Sync();
        	this.FHasEmissiveTexture.Sync();
        	this.FHasDiffuseTexture.Sync();
        	this.FHasSpecularTexture.Sync();
        	this.FHasSpecularPowerTexture.Sync();
        	this.FHasNormalTexture.Sync();
        	this.FHasBumpTexture.Sync();
        	this.FHasOpacityTexture.Sync();
        	this.FBumpIntensity.Sync();
        	this.FSpecularScale.Sync();
        	this.FAlphaThreshold.Sync();

            for (int i = 0; i < count; i++)
            {
                buffer[i].GlobalAmbient = this.FGlobalAmbient[i].ToVector4();
            	buffer[i].AmbientColor = this.FAmbientColor[i].ToVector4();
            	buffer[i].EmissiveColor = this.FEmissiveColor[i].ToVector4();
            	buffer[i].DiffuseColor = this.FDiffuseColor[i].ToVector4();
            	buffer[i].SpecularColor = this.FSpecularColor[i].ToVector4();
            	buffer[i].Reflectance = this.FReflectance[i].ToVector4();
            	buffer[i].Opacity = this.FOpacity[i];
            	buffer[i].SpecularPower = this.FSpecularPower[i];
            	buffer[i].HasAmbientTexture = this.FHasAmbientTexture[i]? 1 : 0;
            	buffer[i].HasEmissiveTexture = this.FHasEmissiveTexture[i]? 1 : 0;
            	buffer[i].HasDiffuseTexture = this.FHasDiffuseTexture[i]? 1 : 0;
            	buffer[i].HasSpecularTexture = this.FHasSpecularTexture[i]? 1 : 0;
            	buffer[i].HasSpecularPowerTexture = this.FHasSpecularPowerTexture[i]? 1 : 0;
            	buffer[i].HasNormalTexture = this.FHasNormalTexture[i]? 1 : 0;
            	buffer[i].HasBumpTexture = this.FHasBumpTexture[i]? 1 : 0;
            	buffer[i].HasOpacityTexture = this.FHasOpacityTexture[i]? 1 : 0;
            	buffer[i].BumpIntensity = this.FBumpIntensity[i];
            	buffer[i].SpecularScale = this.FSpecularScale[i];
            	buffer[i].AlphaThreshold = this.FAlphaThreshold[i];
            }
        }
    }
}
