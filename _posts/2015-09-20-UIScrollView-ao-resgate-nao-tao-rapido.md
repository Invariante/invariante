---
layout: post
title: UIScrollView ao resgate, não tão rápido...
---

Bem vindo ao Invariante, este é o nosso primeiro *post*. A idéia do blog é postar no mínimo dois artigos por mês, se quiser saber mais sobre a gente vá em [Sobre](/sobre).

---
A cada ano aumenta a variedade de dispositivos iOS com tamanhos de telas diferentes e assim o *Auto Layout* se torna cada vez mais importante no desenvolvimento. Já usei muito *autoresizingMask* e calculei muito *frame* na mão, mas tenho apreciado cada vez mais o *Auto Layout* e tenho feito dele minha principal ferramenta de *layout*.
Entretanto essa semana me deparei com um problema imune ao *Auto Layout*, talvez devido minha falta de habilidade ¯\\\_(ツ)_/¯. 

A idéia é ter uma `View2` que pertence a um *view controller* 2 dentro de uma `View1` pertencente a um *view controller* 1. A `View2` pode ter um tamanho arbitrário definido pelo *view controller* 1.
A `View2` irá conter uma imagem que deve ser centralizada, o tamanho dessa imagem é arbitrário e deve ser redimensionado de maneira que a distância do lado maior mais próximo da borda seja de `x` pontos.

![UIScrollView1](/public/imgs/uiscrollview-1.jpg)

Até ai nada de complicado, mas também é necessário que seja possível fazer *zoom* e *scroll* da imagem e a margem de `x` pontos seja mantida independente da ampliação.

![UIScrollView2](/public/imgs/uiscrollview-2.jpg)

Bom nossa boa e velha amiga `UIScrollView` parece ser uma ótima candidata para salvar o dia mas, para isso, precisamos entender melhor com ela funciona. Uma ótima referência é um artigo da edição sobre *views* do objc.io, [Understanding Scroll Views](https://www.objc.io/issues/3-views/scroll-view/). Vou resumir alguns conceitos básicos e colocar um pouco da minha visão mas o recomendo a leitura do artigo, assim como os outros artigos dessa edição sobre *views*. Para entender como uma *scroll view* funciona precisamos entender o que significam 3 propriedades: `contentOffset`, `contentSize` e `contentInset`.

![UIScrollView3](/public/imgs/uiscrollview-3.jpg)

##`contentOffset`

O `contentOffset` define a posição do *scroll*, isto é, o deslocamento das *sub views* da *scroll view*. Na prática ela é a `origin` do `bounds` da *scroll view*, mas alguém poderia perguntar: a origem não é sempre `{0,0}`? Nem sempre, um ponto qualquer (`{xS,yS}`) de uma `subView` é convertido para o sistema de coordenadas (`{x,y}`) de sua *super view* (`view`) da seguinte forma:

{% highlight objective-c %}
x = xS + subView.frame.origin.x + view.bounds.origin.x
y = yS + subView.frame.origin.y + view.bounds.origin.y
{% endhighlight %}

Como normalmente `view.bounds.origin = {0,0}` para calcular a posição de um ponto qualquer da `subView ` na `view` é só somar a origem do `frame` da `subView`.
Isso significa que quando mudamos a `origin` do `bounds` de uma *view*, todas as suas *sub views* vão ser deslocadas pela a mesma quantidade, truque maroto!

Se consideramos que a `UIImageView` tem `origin = {0,0}` o `contentOffset` é a distância entre o canto superior esquerdo da *image view* e o da *scroll view*, como ilustrado na figura acima.

##`contentSize`

É o tamanho do conteúdo apresentado, no caso da figura o `contentSize` é igual o `frame.size` da *image view*. Num caso geral ele só depende do tamanho e disposição das *sub views*, nunca da *scroll view*.

##`contentInset`

Usado para definir uma margem para apresentação do conteúdo, por padrão seu valor é `{0,0,0,0}`, e portanto o tamanho da área que pode apresentar conteúdo é igual à `scrollView.frame`.

Quando o `contentSize` for menor que o tamanho da *scroll view* isso significa que as *sub views* irão ficar no canto superior esquerda, fixas. Uma maneira de centralizar o conteúdo é colocar um *inset* como metade da diferença de tamanho entre a *scroll view* e o `contentSize`:

{% highlight objective-c %}
CGFloat xInset = (CGRectGetWidth(scrollView.frame) - scrollView.contentSize.width)/2.;
CGFloat yInset = (CGRectGetHeight(scrollView.frame) - scrollView.contentSize.height)/2.;

scrollView.contentInset = UIEdgeInsetsMake(yInset, xInset, yInset, xInset);
{% endhighlight %}

Quando o `contentSize` for maior que que a *scroll view* o `contentInset` define os limites máximos de *scroll*. Por exemplo no caso da `UIImageView` que tem a `frame.origin = {0,0}`, os limites da `UIImageView` não podem "entrar" na área definida pelo `frame` da *scrool view* descontado o `contentInset`. A figura abaixo deve deixar isso mais claro.

![UIScrollView4](/public/imgs/uiscrollview-4.jpg)

Ok, agora fica fácil escrever o código que adiciona uma imagem à uma *scroll view* e define essas propriedades corretamente:

{% highlight objective-c %}
- (void)updateWithImage:(UIImage *)image
{
    UIScrollView *scrollView = self.scrollView;
    UIImageView *imageView = self.imageView;
    
    imageView.image = image;
    CGSize imageSize = image.size;
    CGRect imageFrame = CGRectMake(0, 0, imageSize.width, imageSize.height);
    
    imageView.frame = imageFrame;
    scrollView.contentSize = imageSize;
    
    CGRect scrollViewFrame = scrollView.frame;
    
    // Set Inset
    UIEdgeInsets insets = self.scrollViewDefaultInset;
    insets = [self insetsForContentFrame:imageFrame
               insideScrollViewWithFrame:scrollViewFrame
                       withDefaultInsets:insets];
    scrollView.contentInset = insets;
    
    // Set Zoom
    CGSize scrollViewSize = CGSizeMake(CGRectGetWidth(scrollViewFrame) - insets.left - insets.right,
                                       CGRectGetHeight(scrollViewFrame) - insets.top - insets.bottom);
    CGFloat xMinZoomScale = scrollViewSize.width/(imageSize.width + 2. * kMargin);
    CGFloat yMinZoomScale = scrollViewSize.height/(imageSize.height + 2. * kMargin);
    CGFloat minimumZoomScale = MIN(xMinZoomScale, yMinZoomScale);
    scrollView.minimumZoomScale = minimumZoomScale;
    scrollView.maximumZoomScale = minimumZoomScale * kMaxZoomFactor;
    
    // Fit on screen
    scrollView.zoomScale = minimumZoomScale;
}
{% endhighlight %}

Sendo que função que calcula os *insets* é:
{% highlight objective-c %}
- (UIEdgeInsets)insetsForContentFrame:(CGRect)contentFrame
            insideScrollViewWithFrame:(CGRect)scrollViewFrame
                    withDefaultInsets:(UIEdgeInsets)insets
{
    CGSize contentSize = contentFrame.size;
    CGSize scrollViewSize = CGSizeMake(CGRectGetWidth(scrollViewFrame) - insets.left - insets.right,
                                       CGRectGetHeight(scrollViewFrame) - insets.top - insets.bottom);
    CGFloat margin = kMargin;
    
    CGFloat xInset = MAX((scrollViewSize.width - contentSize.width)/2., margin);
    CGFloat yInset = MAX((scrollViewSize.height - contentSize.height)/2., margin);
    
    insets.left += xInset;
    insets.right += xInset;
    insets.top += yInset;
    insets.bottom += yInset;

    return insets;
}
{% endhighlight %}

Para habilitar o *zoom* só falta implementar um método do `UIScrollViewDelegate`:

{% highlight objective-c %}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}
{% endhighlight %}

Esse método apenas retorna qual a *view* que será aplicado o *zoom*, da primeira vez que vi achei muito estranho, mas entender como a `UIScrollView` faz o *zoom* tudo ficou muito mais claro.

##Bônus: `zoomScale`

A `UIScrollView` faz *zoom* aplicando uma transformação na *view* retornada pelo método do *delagate* descrito acima. Isto é, 
aplica uma `CGAffineTransform` do tipo `CGAffineTransformMakeScale(zoomScale, zoomScale)` na *subview*. Isso faz com que o `frame` da `subView` seja alterado! E, portanto, o `contentSize` da `scrollView`, por isso sempre que o `contentSize` e, consequentemente, o `zoomScale` forem alterados o `contentInset` deve ser recalculado. Isso pode ser feito facilmente implementando mais um método do *delegate*:

{% highlight objective-c %}
- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    UIEdgeInsets insets = self.scrollViewDefaultInset;
    
    insets = [self insetsForContentFrame:self.imageView.frame
               insideScrollViewWithFrame:scrollView.frame
                       withDefaultInsets:insets];
    
    scrollView.contentInset = insets;
}
{% endhighlight %}

A `UIScrollView` é uma classe muito importante no `UIKit`, seu funcionamento é muito simples, mas entender como ela exatamente funciona pode não ser uma tarefa muito simples.

Um exemplo dessa solução funcionando pode ser encontrada no repositório [UIScrollView-Center](https://github.com/diogot/UIScrollView-Center).
Qualquer dúvida, críticas e comentários são bem vindos, a maneira mais fácil de me encontrar é no [Twitter](http://twitter.com/diogot).

---
Diogo Tridapalli <br />
[@diogot](http://twitter.com/diogot)