// Remplacer null par le chemin du fichier original lorsque le logo est fourni comme fichier.
export const LOGO_ASSET:string|null=null;
export function Brand({compact=false}:{compact?:boolean}){return <span className={'propulse-brand '+(compact?'compact':'')}>{LOGO_ASSET?<img src={LOGO_ASSET} alt="Propulse — boost your business"/>:<span className="propulse-wordmark">propulse<span className="propulse-tagline">boost your business</span></span>}{!compact&&<span className="brand-product">STUDIO · ESPACE CRÉATIF</span>}</span>}
